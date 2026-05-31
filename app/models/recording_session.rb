class RecordingSession < ApplicationRecord
  MAX_AUDIO_SIZE = 100.megabytes
  DASHBOARD_RECENT_LIMIT = 8
  ALLOWED_AUDIO_CONTENT_TYPES = %w[
    audio/aac
    audio/flac
    audio/mpeg
    audio/mp3
    audio/mp4
    audio/ogg
    audio/wav
    audio/webm
    video/mp4
    video/webm
  ].freeze

  belongs_to :workspace
  belongs_to :creator, class_name: "User"
  has_one :document, dependent: :destroy
  has_one_attached :original_audio
  has_one_attached :normalized_audio

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }, default: :pending
  enum :source_kind, { upload: 0, microphone: 1 }, default: :upload

  normalizes :title, with: ->(title) { title.to_s.strip }
  normalizes :transformer_handle, with: ->(handle) { handle.to_s.strip.presence || TransformerProfile::DEFAULT_HANDLE }

  validates :title, presence: true
  validates :transformer_handle, presence: true, format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ }
  validate :original_audio_is_supported

  scope :recent_first, -> { order(created_at: :desc) }

  before_validation :assign_default_title, on: :create

  def mark_processing!
    update!(
      status: :processing,
      error_message: nil,
      processing_started_at: Time.current,
      processing_completed_at: nil
    )
    broadcast_dashboard_recording_sessions
  end

  def mark_completed!(transcript_text:, document_content:, work_path:, generated_at: Time.current)
    transaction do
      update!(
        status: :completed,
        transcript_text: transcript_text,
        error_message: nil,
        work_path: work_path,
        processing_completed_at: generated_at
      )
      document&.destroy!
      create_document!(
        workspace: workspace,
        transformer_handle: transformer_handle,
        title: title,
        content: document_content,
        generated_at: generated_at
      )
    end
    broadcast_dashboard
  end

  def mark_failed!(message)
    update!(
      status: :failed,
      error_message: message.to_s.truncate(500),
      processing_completed_at: Time.current
    )
    broadcast_dashboard_recording_sessions
  end

  private

  def broadcast_dashboard
    broadcast_dashboard_recording_sessions
    broadcast_dashboard_documents
  end

  def broadcast_dashboard_recording_sessions
    Turbo::StreamsChannel.broadcast_replace_to(
      dashboard_stream,
      target: "dashboard_recording_sessions",
      partial: "dashboard/recording_sessions",
      locals: { recording_sessions: dashboard_recording_sessions }
    )
  end

  def broadcast_dashboard_documents
    Turbo::StreamsChannel.broadcast_replace_to(
      dashboard_stream,
      target: "dashboard_finished_documents",
      partial: "dashboard/finished_documents",
      locals: { documents: dashboard_documents }
    )
  end

  def dashboard_stream
    [ workspace, :dashboard ]
  end

  def dashboard_recording_sessions
    workspace.recording_sessions.includes(:document, original_audio_attachment: :blob).recent_first.limit(DASHBOARD_RECENT_LIMIT)
  end

  def dashboard_documents
    workspace.documents.includes(:recording_session).recent_first.limit(DASHBOARD_RECENT_LIMIT)
  end

  def assign_default_title
    self.title = "Untitled recording" if title.blank?
  end

  def original_audio_is_supported
    unless original_audio.attached?
      errors.add(:original_audio, "is required")
      return
    end

    blob = original_audio.blob
    content_type = blob.content_type.to_s.split(";").first
    errors.add(:original_audio, "must be an audio file") unless ALLOWED_AUDIO_CONTENT_TYPES.include?(content_type)
    errors.add(:original_audio, "must be smaller than 100 MB") if blob.byte_size > MAX_AUDIO_SIZE
  end
end

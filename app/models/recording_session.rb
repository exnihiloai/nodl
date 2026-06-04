class RecordingSession < ApplicationRecord
  DEFAULT_TITLE = "Untitled recording".freeze
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

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3, recording: 4 }, default: :pending
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
    broadcast_dashboard_activity
    broadcast_live_transcript_panel
  end

  def mark_completed!(transcript_text:, document_content:, work_path:, transcript_segments: nil, generated_title: nil, generated_at: Time.current)
    attributes = {
      status: :completed,
      transcript_text: transcript_text,
      transcript_segments: transcript_segments,
      error_message: nil,
      work_path: work_path,
      processing_completed_at: generated_at
    }
    attributes[:title] = generated_title if generated_title.present?

    transaction do
      update!(attributes)
      document&.destroy!
      create_document!(
        workspace: workspace,
        transformer_handle: transformer_handle,
        title: self.title,
        content: document_content,
        generated_at: generated_at
      )
    end
    broadcast_dashboard_activity
    broadcast_live_transcript_panel
  end

  def mark_failed!(message)
    update!(
      status: :failed,
      error_message: message.to_s.truncate(500),
      processing_completed_at: Time.current
    )
    broadcast_dashboard_activity
    broadcast_live_transcript_panel
  end

  def live_stream
    [ self, :live ]
  end

  def default_title?
    title == DEFAULT_TITLE
  end

  private

  def broadcast_dashboard_activity
    Turbo::StreamsChannel.broadcast_replace_to(
      dashboard_stream,
      target: "dashboard_activity",
      partial: "dashboard/activity",
      locals: { recording_sessions: dashboard_recording_sessions }
    )
  end

  def dashboard_stream
    [ workspace, :dashboard ]
  end

  def dashboard_recording_sessions
    workspace.recording_sessions.includes(:document, original_audio_attachment: :blob).recent_first.limit(DASHBOARD_RECENT_LIMIT)
  end

  def assign_default_title
    self.title = DEFAULT_TITLE if title.blank?
  end

  def original_audio_is_supported
    unless original_audio.attached?
      return if recording?

      errors.add(:original_audio, "is required")
      return
    end

    blob = original_audio.blob
    content_type = blob.content_type.to_s.split(";").first
    errors.add(:original_audio, "must be an audio file") unless ALLOWED_AUDIO_CONTENT_TYPES.include?(content_type)
    errors.add(:original_audio, "must be smaller than 100 MB") if blob.byte_size > MAX_AUDIO_SIZE
  end

  def broadcast_live_transcript_panel
    Turbo::StreamsChannel.broadcast_replace_to(
      live_stream,
      target: "live_transcript_panel",
      partial: "recording_sessions/live_transcript_panel",
      locals: { recording_session: self }
    )
  end
end

require "fileutils"
require "pathname"
require "nodl/audio/duration_probe"

class RecordingSession < ApplicationRecord
  DEFAULT_TITLE = "Untitled recording".freeze
  MAX_AUDIO_SIZE = 100.megabytes
  DASHBOARD_RECENT_LIMIT = 8
  WORK_SESSIONS_ROOT = Rails.root.join("work", "sessions").freeze
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
  ORIGINAL_AUDIO_DOWNLOAD_EXTENSIONS = {
    "audio/aac" => ".aac",
    "audio/flac" => ".flac",
    "audio/mpeg" => ".mp3",
    "audio/mp3" => ".mp3",
    "audio/mp4" => ".m4a",
    "audio/ogg" => ".ogg",
    "audio/wav" => ".wav",
    "audio/webm" => ".webm",
    "video/mp4" => ".m4a",
    "video/webm" => ".webm"
  }.freeze

  belongs_to :workspace
  belongs_to :creator, class_name: "User"
  has_one :document, dependent: :destroy
  has_one :integrity_record, class_name: "RecordingIntegrityRecord", dependent: :destroy
  # Pinned to the encrypted service (see config.x.attachment_service) so every
  # blob is stored encrypted at rest with its own key.
  has_one_attached :original_audio, service: Rails.application.config.x.attachment_service
  has_one_attached :normalized_audio, service: Rails.application.config.x.attachment_service

  # Encrypt tenant-scoped content at rest with Active Record Encryption. Stored
  # as ciphertext in Postgres; transparent to the rest of the app. Non-deterministic
  # (these columns are never queried/ordered by value). transcript_segments is
  # JSON-serialized first because encrypted attributes persist as a string.
  serialize :transcript_segments, coder: JSON
  encrypts :transcript_text
  encrypts :transcript_segments
  encrypts :title

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3, recording: 4 }, default: :pending
  enum :source_kind, { upload: 0, microphone: 1 }, default: :upload

  normalizes :title, with: ->(title) { title.to_s.strip }
  normalizes :transformer_handle, with: ->(handle) { handle.to_s.strip.presence || TransformerProfile::DEFAULT_HANDLE }
  # The browser reports an IANA zone (e.g. "Europe/Vienna") at record time. Keep
  # it only when it names a real zone, so a bogus value silently falls back to
  # the app default instead of blocking the recording.
  normalizes :time_zone, with: ->(value) {
    zone = value.to_s.strip.presence
    zone if zone && ActiveSupport::TimeZone[zone]
  }

  validates :title, presence: true
  validates :transformer_handle, presence: true, format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ }
  validate :original_audio_is_supported
  validate :original_audio_duration_within_limit, if: :validate_original_audio_duration?
  validate :workspace_recording_limit_not_exceeded, on: :create

  scope :recent_first, -> { order(created_at: :desc) }
  # A microphone session sits in :recording only between hitting record and the
  # audio being finalized — until then it has no content. Exclude those rows so
  # an abandoned/in-progress capture never shows as a stuck "Structuring..."
  # row in the dashboard list or counts against the workspace recording quota.
  scope :finalized, -> { where.not(status: :recording) }

  before_validation :assign_default_title, on: :create
  after_create_commit :record_recording_usage
  after_destroy_commit :remove_work_path

  def mark_processing!
    update!(
      status: :processing,
      error_message: nil,
      processing_started_at: Time.current,
      processing_completed_at: nil
    )
    broadcast_dashboard_activity
    broadcast_live_transcript_status
  end

  def mark_completed!(transcript_text:, document_content:, work_path:, transcript_segments: nil, waveform_peaks: nil, audio_duration: nil, generated_title: nil, generated_at: Time.current)
    attributes = {
      status: :completed,
      transcript_text: transcript_text,
      transcript_segments: transcript_segments,
      waveform_peaks: waveform_peaks,
      audio_duration: audio_duration,
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
    TrialRecordingsBadge.new(workspace).broadcast!
    TrialAhaMoment.new(self).broadcast!
  end

  def mark_failed!(message)
    update!(
      status: :failed,
      error_message: message.to_s.truncate(500),
      processing_completed_at: Time.current
    )
    broadcast_dashboard_activity
    broadcast_live_transcript_status
  end

  def live_stream
    [ self, :live ]
  end

  # Audio to play back in the app. Prefer the normalized copy when present: it
  # is what Voxtral transcribed (so timestamps line up exactly) and always has a
  # reliable duration, unlike raw microphone WebM.
  def playback_audio
    normalized_audio.attached? ? normalized_audio : original_audio
  end

  def original_audio_downloadable?
    original_audio.attached? && !recording? && !processing?
  end

  def original_audio_download_filename
    original_filename = sanitized_original_audio_filename
    return original_filename if original_filename.present?

    "#{original_audio_download_basename}-#{original_audio_download_timestamp}#{original_audio_download_extension}"
  end

  def default_title?
    title == DEFAULT_TITLE
  end

  # When the recording was created, expressed in the recorder's local zone when
  # we captured one (so "today"/"right now" references resolve to the speaker's
  # wall clock), otherwise the app default zone.
  def local_created_at
    return created_at if created_at.nil? || time_zone.blank?

    created_at.in_time_zone(time_zone)
  end

  def estimated_duration
    return audio_duration if audio_duration.present? && audio_duration > 0

    if original_audio.attached?
      blob = original_audio.blob
      if blob.metadata.is_a?(Hash)
        # Check direct duration
        dur = blob.metadata[:duration] || blob.metadata["duration"]
        return dur.to_f if dur.present?

        # Check bit rate to compute duration perfectly
        br = blob.metadata[:bit_rate] || blob.metadata["bit_rate"]
        return (blob.byte_size * 8.0 / br.to_f) if br.present? && br.to_f > 0
      end

      # Fallback based on average audio recording bitrate (e.g., 64 kbps = 8000 bytes/sec)
      return blob.byte_size.to_f / 8000.0
    end

    0.0
  end

  private

  def broadcast_dashboard_activity
    Turbo::StreamsChannel.broadcast_replace_to(
      [ workspace, :dashboard ],
      target: "dashboard_activity",
      partial: "dashboard/activity",
      locals: { recording_sessions: dashboard_recording_sessions }
    )
  end

  def dashboard_recording_sessions
    workspace.recording_sessions.finalized.includes(:document, original_audio_attachment: :blob).recent_first.limit(DASHBOARD_RECENT_LIMIT)
  end

  def remove_work_path
    return if work_path.blank?

    path = Pathname.new(work_path).cleanpath
    root = WORK_SESSIONS_ROOT.cleanpath
    return unless path.to_s.start_with?("#{root}/")

    FileUtils.rm_rf(path)
  end

  def assign_default_title
    self.title = DEFAULT_TITLE if title.blank?
  end

  def sanitized_original_audio_filename
    return unless original_audio.attached?

    filename = original_audio.filename.to_s.tr("\\", "/").split("/").last.to_s
    extension = File.extname(filename).downcase.gsub(/[^.a-z0-9]/, "")
    basename = File.basename(filename, ".*").parameterize
    return if basename.blank?

    "#{basename}#{extension.presence || original_audio_download_extension}"
  end

  def original_audio_download_basename
    title.to_s.parameterize.presence || "recording"
  end

  def original_audio_download_timestamp
    timestamp = local_created_at || created_at || Time.current
    timestamp.strftime("%Y%m%d-%H%M")
  end

  def original_audio_download_extension
    return ".audio" unless original_audio.attached?

    filename_extension = original_audio.filename.extension_with_delimiter.to_s.downcase
    return filename_extension if filename_extension.match?(/\A\.[a-z0-9]+\z/)

    content_type = original_audio.blob.content_type.to_s.split(";").first
    ORIGINAL_AUDIO_DOWNLOAD_EXTENSIONS.fetch(content_type, ".audio")
  end

  def original_audio_is_supported
    unless original_audio.attached?
      return if recording?

      errors.add(:original_audio, "is required")
      return
    end

    blob = original_audio.blob
    content_type = original_audio_content_type
    errors.add(:original_audio, "must be an audio file") unless ALLOWED_AUDIO_CONTENT_TYPES.include?(content_type)
    errors.add(:original_audio, :empty) if blob.byte_size.zero?
    errors.add(:original_audio, "must be smaller than 100 MB") if blob.byte_size > MAX_AUDIO_SIZE
  end

  def original_audio_duration_within_limit
    duration = measured_original_audio_duration
    if duration.nil? || duration <= 0
      errors.add(:original_audio, :invalid_or_interrupted)
      return
    end

    result = workspace.entitlement_for(:max_recording_duration_seconds, quantity: duration, unit: "seconds")
    return if result.allowed?

    errors.add(:original_audio, :too_long, limit: (result.limit.to_f / 60).ceil)
  end

  def validate_original_audio_duration?
    return false unless original_audio.attached?
    return false unless original_audio_content_type_supported?
    return false if original_audio.blob.byte_size.zero?
    return false if microphone? && persisted?

    new_record? || attachment_changes.key?("original_audio")
  end

  def original_audio_content_type_supported?
    ALLOWED_AUDIO_CONTENT_TYPES.include?(original_audio_content_type)
  end

  def original_audio_content_type
    original_audio.blob.content_type.to_s.split(";").first
  end

  def workspace_recording_limit_not_exceeded
    return if workspace.blank?
    result = workspace.entitlement_for(:recordings)
    return if result.allowed?

    errors.add(:base, :recording_limit_reached, limit: result.limit)
  end

  def record_recording_usage
    UsageRecorder.record!(workspace:, user: creator, event_kind: "recording_created", subject: self)
  end

  def measured_original_audio_duration
    return @measured_original_audio_duration if defined?(@measured_original_audio_duration)

    @measured_original_audio_duration = Nodl::Audio::DurationProbe.new(
      attachment: original_audio,
      attachment_change: attachment_changes["original_audio"]
    ).duration
  end

  def broadcast_live_transcript_panel
    Turbo::StreamsChannel.broadcast_replace_to(
      live_stream,
      target: "live_transcript_panel",
      partial: "recording_sessions/live_transcript_panel",
      locals: { recording_session: self }
    )
  end

  # Updates only the status header (badge + helper text), leaving the live
  # preview text in #live_transcript_segments untouched. Used while finalizing
  # and on failure so the user keeps seeing what they just dictated instead of
  # the panel blanking out.
  def broadcast_live_transcript_status
    Turbo::StreamsChannel.broadcast_replace_to(
      live_stream,
      target: "live_transcript_status",
      partial: "recording_sessions/live_transcript_status",
      locals: { recording_session: self }
    )
  end
end

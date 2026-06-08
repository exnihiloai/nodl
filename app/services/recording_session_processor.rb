require "tempfile"
require "fileutils"
require "nodl/audio/normalizer"
require "nodl/pipeline"

class RecordingSessionProcessor
  DEFAULT_TRANSCRIBER_MODEL = "voxtral-mini-latest"
  DEFAULT_TRANSFORMER_MODEL = "gemini-3.1-flash-lite"

  # Privacy: telemetry/notifications must never disclose document content, so we
  # only ever expose a short preview of the title (first N characters + ellipsis)
  # in the nodl.document.generated payload. The full title stays out of the event.
  TITLE_PREVIEW_LENGTH = 6

  def self.redacted_title(title)
    clean = title.to_s.strip
    return "Untitled" if clean.empty?

    clean.length > TITLE_PREVIEW_LENGTH ? "#{clean[0, TITLE_PREVIEW_LENGTH]}..." : clean
  end

  def initialize(
    normalizer: Nodl::Audio::Normalizer.new,
    pipeline: Nodl::Pipeline.new,
    title_generator: nil
  )
    @normalizer = normalizer
    @pipeline = pipeline
    @title_generator = title_generator
  end

  def call(recording_session)
    recording_session.mark_processing!
    ActiveSupport::Notifications.instrument("nodl.recording.processing_started", recording_session: recording_session)

    with_original_audio_file(recording_session) do |audio_path|
      normalized = normalizer.normalize(
        input_path: audio_path,
        content_type: recording_session.original_audio.blob.content_type,
        original_filename: recording_session.original_audio.filename.to_s
      )
      attach_normalized_audio(recording_session, normalized) if normalized.converted?
      waveform = Nodl::Audio::WaveformExtractor.new.extract(normalized.path)
      enforce_recording_duration!(waveform.duration)
      result = pipeline.run(
        audio_path: normalized.path,
        transformer_handle: recording_session.transformer_handle,
        workspace: recording_session.workspace,
        transcriber_model: ENV.fetch("NODL_VOXTRAL_MODEL", DEFAULT_TRANSCRIBER_MODEL),
        transformer_model: ENV.fetch("NODL_GEMINI_TRANSFORMER_MODEL", DEFAULT_TRANSFORMER_MODEL),
        recorded_at: recording_session.local_created_at
      )
      transcript_text = result.transcript_path.read.strip
      document_content = result.document_path.read.strip
      recording_session.mark_completed!(
        transcript_text: transcript_text,
        transcript_segments: result.transcript_segments,
        waveform_peaks: result.waveform_peaks,
        audio_duration: result.audio_duration,
        document_content: document_content,
        work_path: result.session_path.to_s,
        generated_title: generated_title_for(recording_session, transcript_text)
      )
      ActiveSupport::Notifications.instrument(
        "nodl.document.generated",
        recording_session: recording_session,
        redacted_title: self.class.redacted_title(recording_session.title)
      )
    ensure
      FileUtils.rm_f(normalized.path) if normalized&.converted?
    end
  rescue StandardError => error
    recording_session.mark_failed!(error.message)
    raise
  end

  private

  attr_reader :normalizer, :pipeline, :title_generator

  def enforce_recording_duration!(duration)
    return if duration.to_f <= PlanLimits.max_recording_duration_seconds

    raise Nodl::Error, I18n.t(
      "activerecord.errors.models.recording_session.attributes.original_audio.too_long",
      limit: PlanLimits::MAX_RECORDING_DURATION.in_minutes.to_i
    )
  end

  def generated_title_for(recording_session, transcript_text)
    return unless recording_session.default_title?

    (title_generator || RecordingTitleGenerator.new).generate(
      transcript: transcript_text,
      recorded_at: recording_session.local_created_at
    )
  rescue StandardError => error
    Rails.logger.warn(
      "Recording title generation failed " \
      "recording_session_id=#{recording_session.id} " \
      "error_class=#{error.class} " \
      "error_message=#{error.message}"
    )
    nil
  end

  def with_original_audio_file(recording_session)
    extension = recording_session.original_audio.filename.extension_with_delimiter.presence || ".audio"
    Tempfile.create([ "recording-session-#{recording_session.id}", extension ], binmode: true) do |file|
      file.write(recording_session.original_audio.download)
      file.flush
      yield Pathname.new(file.path)
    end
  end

  def attach_normalized_audio(recording_session, normalized)
    File.open(normalized.path, "rb") do |file|
      recording_session.normalized_audio.attach(
        io: file,
        filename: normalized.filename,
        content_type: normalized.content_type
      )
    end
  end
end

require "tempfile"
require "pathname"
require "nodl/transcription/gemini_transcriber"

class TranscribeSegmentJob < ApplicationJob
  queue_as :default

  DEFAULT_MODEL = "gemini-3.1-flash-lite".freeze
  SegmentAudio = Struct.new(:path, :mime_type, :basename, keyword_init: true)

  def perform(recording_session_id, blob_signed_id, index)
    recording_session = RecordingSession.find(recording_session_id)
    blob = ActiveStorage::Blob.find_signed!(blob_signed_id)
    return blob.purge unless recording_session.recording?

    with_blob_file(blob) do |path|
      result = Nodl::Transcription::GeminiTranscriber.new.transcribe(
        audio: SegmentAudio.new(path: Pathname.new(path), mime_type: blob.content_type, basename: blob.filename.to_s),
        model: ENV.fetch("NODL_GEMINI_LIVE_TRANSCRIBER_MODEL", DEFAULT_MODEL),
        preview: true
      )
      recording_session.store_live_segment_text(index, result.text)
      broadcast_preview(recording_session)
    end
  rescue StandardError => error
    Rails.logger.warn("Live transcription segment failed: #{error.class}: #{error.message}")
  ensure
    blob&.purge
  end

  private

  def with_blob_file(blob)
    extension = blob.filename.extension_with_delimiter.presence || ".audio"
    Tempfile.create([ "recording-segment-#{blob.id}", extension ], binmode: true) do |file|
      file.write(blob.download)
      file.flush
      yield file.path
    end
  end

  def broadcast_preview(recording_session)
    Turbo::StreamsChannel.broadcast_replace_to(
      recording_session.live_stream,
      target: "live_transcript_segments",
      partial: "recording_sessions/live_transcript_segments",
      locals: { segments: recording_session.live_transcript_segments }
    )
  end
end

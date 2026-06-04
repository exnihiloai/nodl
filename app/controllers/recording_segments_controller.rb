class RecordingSegmentsController < ApplicationController
  before_action :authenticate_user!

  def create
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    recording_session = current_workspace.recording_sessions.find(params[:recording_session_id])
    return head :unprocessable_entity unless recording_session.recording?

    segment = params.require(:segment)
    index = params.require(:index).to_i
    blob = ActiveStorage::Blob.create_and_upload!(
      io: segment.tempfile,
      filename: segment.original_filename.presence || "recording-segment.webm",
      content_type: segment.content_type
    )

    TranscribeSegmentJob.perform_later(recording_session.id, blob.signed_id, index)
    Rails.logger.info(
      "Live transcription segment enqueued " \
      "recording_session_id=#{recording_session.id} " \
      "index=#{index} " \
      "bytes=#{blob.byte_size} " \
      "duration_ms=#{elapsed_ms(started_at)}"
    )
    head :accepted
  end

  private

  def elapsed_ms(started_at)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
  end
end

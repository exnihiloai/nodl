class RecordingSegmentsController < ApplicationController
  before_action :authenticate_user!

  def create
    recording_session = current_workspace.recording_sessions.find(params[:recording_session_id])
    return head :unprocessable_entity unless recording_session.recording?

    segment = params.require(:segment)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: segment.tempfile,
      filename: segment.original_filename.presence || "recording-segment.webm",
      content_type: segment.content_type
    )

    TranscribeSegmentJob.perform_later(recording_session.id, blob.signed_id, params.require(:index).to_i)
    head :accepted
  end
end

require_dependency Rails.root.join("app/services/recording_session_processor").to_s

class ProcessRecordingSessionJob < ApplicationJob
  queue_as :default

  def perform(recording_session_id)
    recording_session = RecordingSession.find_by(id: recording_session_id)
    return unless recording_session

    RecordingSessionProcessor.new.call(recording_session)
  rescue StandardError => error
    if recording_session && !recording_session.reload.failed?
      recording_session.mark_failed!(error.message)
    end
    raise
  end
end

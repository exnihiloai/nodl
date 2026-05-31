require_dependency Rails.root.join("app/services/recording_session_processor").to_s

class ProcessRecordingSessionJob < ApplicationJob
  queue_as :default

  def perform(recording_session_id)
    recording_session = RecordingSession.find(recording_session_id)
    RecordingSessionProcessor.new.call(recording_session)
  rescue StandardError => error
    recording_session&.mark_failed!(error.message)
    raise
  end
end

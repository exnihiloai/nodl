require "nodl/integrity/recording_integrity_service"

class SealRecordingIntegrityJob < ApplicationJob
  queue_as :default

  def perform(recording_session_id)
    recording_session = RecordingSession.includes(:creator, original_audio_attachment: :blob).find_by(id: recording_session_id)
    return unless recording_session

    return unless recording_session.creator.integrity_sealing_enabled?
    return unless recording_session.original_audio.attached?

    result = Nodl::Integrity::RecordingIntegrityService.seal_blob(recording_session.original_audio.blob)
    Nodl::Integrity::RecordingIntegrityService.upsert!(recording_session, result)
  rescue StandardError => error
    Rails.logger.warn(
      "Recording integrity sealing failed " \
      "recording_session_id=#{recording_session_id} " \
      "error_class=#{error.class} " \
      "error_message=#{error.message}"
    )
  end
end

class RetryRecordingIntegritySealsJob < ApplicationJob
  queue_as :default

  def perform
    RecordingIntegrityRecord
      .retryable
      .includes(recording_session: [ :creator, { original_audio_attachment: :blob } ])
      .find_each do |record|
        recording_session = record.recording_session
        next unless recording_session.creator.integrity_sealing_enabled?
        next unless recording_session.original_audio.attached?

        SealRecordingIntegrityJob.perform_later(recording_session.id)
      end
  end
end

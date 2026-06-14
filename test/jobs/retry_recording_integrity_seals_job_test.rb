require "test_helper"

class RetryRecordingIntegritySealsJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "enqueues sealing only for retryable records with enabled users" do
    enabled = create_user_with_workspace(email: "retry-enabled@example.test")
    enabled.update!(integrity_sealing_enabled: true)
    disabled = create_user_with_workspace(email: "retry-disabled@example.test")
    disabled.update!(integrity_sealing_enabled: false)

    retryable = recording_with_integrity(user: enabled, status: RecordingIntegrityRecord::STATUS_FAILED)
    recording_with_integrity(user: enabled, status: RecordingIntegrityRecord::STATUS_SEALED)
    recording_with_integrity(user: disabled, status: RecordingIntegrityRecord::STATUS_FAILED)

    assert_enqueued_with(job: SealRecordingIntegrityJob, args: [ retryable.id ]) do
      RetryRecordingIntegritySealsJob.perform_now
    end
    assert_enqueued_jobs 1, only: SealRecordingIntegrityJob
  end

  private

  def recording_with_integrity(user:, status:)
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Retry",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.create_integrity_record!(
      hash_sha256: "a" * 64,
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: status,
      tsa_provider: "rfc3161_freetsa",
      tsa_proof_format: status == RecordingIntegrityRecord::STATUS_SEALED ? RecordingIntegrityRecord::PROOF_FORMAT_RFC3161 : nil,
      tsa_proof_blob: status == RecordingIntegrityRecord::STATUS_SEALED ? "proof" : nil
    )
    recording_session
  end
end

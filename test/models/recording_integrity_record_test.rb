require "test_helper"

class RecordingIntegrityRecordTest < ActiveSupport::TestCase
  test "user integrity sealing is off by default" do
    user = create_user_with_workspace

    assert_not user.integrity_sealing_enabled?
  end

  test "requires a valid status and unique recording session" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Integrity",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    record = recording_session.create_integrity_record!(
      hash_sha256: "a" * 64,
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: RecordingIntegrityRecord::STATUS_SEALED,
      tsa_provider: "rfc3161_freetsa",
      tsa_proof_format: RecordingIntegrityRecord::PROOF_FORMAT_RFC3161,
      tsa_proof_blob: "proof"
    )

    duplicate = RecordingIntegrityRecord.new(
      recording_session: recording_session,
      hash_sha256: "b" * 64,
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: "bogus",
      tsa_provider: "rfc3161_freetsa"
    )

    assert_predicate record, :sealed?
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tsa_status], "is not included in the list"
  end

  test "is destroyed with the recording session" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Integrity",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.create_integrity_record!(
      hash_sha256: "a" * 64,
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: RecordingIntegrityRecord::STATUS_PENDING_CONFIG,
      tsa_provider: "rfc3161_freetsa"
    )

    assert_difference -> { RecordingIntegrityRecord.count }, -1 do
      recording_session.destroy!
    end
  end
end

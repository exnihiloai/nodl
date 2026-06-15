require "test_helper"

class SealRecordingIntegrityJobTest < ActiveJob::TestCase
  test "exits when user feature is disabled" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Disabled",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    Nodl::Integrity::RecordingIntegrityService.expects(:seal_blob).never

    SealRecordingIntegrityJob.perform_now(recording_session.id)

    assert_nil recording_session.reload.integrity_record
  end

  test "creates integrity record when enabled" do
    user = create_user_with_workspace
    user.update!(integrity_sealing_enabled: true)
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Enabled",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    Nodl::Integrity::RecordingIntegrityService.expects(:seal_blob).with(recording_session.original_audio.blob).returns(seal_result)

    assert_difference -> { RecordingIntegrityRecord.count }, 1 do
      SealRecordingIntegrityJob.perform_now(recording_session.id)
    end

    assert_equal RecordingIntegrityRecord::STATUS_PENDING_CONFIG, recording_session.reload.integrity_record.tsa_status
  end

  test "does not mark recording failed when sealing raises" do
    user = create_user_with_workspace
    user.update!(integrity_sealing_enabled: true)
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Enabled",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }
    Nodl::Integrity::RecordingIntegrityService.expects(:seal_blob).raises(StandardError, "offline")

    SealRecordingIntegrityJob.perform_now(recording_session.id)

    assert_predicate recording_session.reload, :completed?
    assert_nil recording_session.integrity_record
  end

  test "exits when the recording session has been deleted" do
    Nodl::Integrity::RecordingIntegrityService.expects(:seal_blob).never

    assert_nothing_raised do
      SealRecordingIntegrityJob.perform_now(-1)
    end
  end

  private

  def seal_result
    Nodl::Integrity::SealResult.new(
      hash_sha256: "a" * 64,
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: RecordingIntegrityRecord::STATUS_PENDING_CONFIG,
      tsa_provider: "rfc3161_freetsa",
      tsa_authority: nil,
      tsa_proof_format: nil,
      tsa_proof_blob: nil,
      tsa_timestamp: nil,
      tsa_error: "TSA URL not configured."
    )
  end
end

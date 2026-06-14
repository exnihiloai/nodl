require "test_helper"

class ReapStaleRecordingSessionsJobTest < ActiveJob::TestCase
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
  end

  teardown do
    @workspace&.destroy
    @user&.destroy
  end

  test "deletes recording-status sessions older than the cutoff" do
    stale = build_recording_session
    stale.update_column(:created_at, 3.hours.ago)

    ReapStaleRecordingSessionsJob.perform_now

    assert_raises(ActiveRecord::RecordNotFound) { stale.reload }
  end

  test "keeps recording-status sessions inside the cutoff" do
    fresh = build_recording_session
    fresh.update_column(:created_at, 5.minutes.ago)

    ReapStaleRecordingSessionsJob.perform_now

    assert_nothing_raised { fresh.reload }
  end

  test "never reaps finalized sessions even when old" do
    completed = @workspace.recording_sessions.create!(
      creator: @user,
      title: "Finished",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }
    completed.update_column(:created_at, 1.week.ago)

    ReapStaleRecordingSessionsJob.perform_now

    assert_nothing_raised { completed.reload }
  end

  private

  def build_recording_session
    @workspace.recording_sessions.create!(
      creator: @user,
      title: "Live recording",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
  end
end

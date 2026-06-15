require "test_helper"

class RecordingSessionDestroyTest < ActiveSupport::TestCase
  test "destroy removes work path under the recording work sessions root" do
    user = create_user_with_workspace
    work_path = RecordingSession::WORK_SESSIONS_ROOT.join("test-#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(work_path)
    work_path.join("document.md").write("# Document\n")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Work cleanup",
      transformer_handle: "default",
      status: :completed,
      work_path: work_path.to_s
    ) { |session| attach_sample_audio(session) }

    recording_session.destroy!

    assert_not Dir.exist?(work_path)
  ensure
    FileUtils.rm_rf(work_path) if work_path
  end

  test "destroy does not remove work path outside the recording work sessions root" do
    user = create_user_with_workspace
    Dir.mktmpdir do |dir|
      outside_path = Pathname.new(dir).join("outside-work")
      FileUtils.mkdir_p(outside_path)
      outside_path.join("keep.txt").write("keep")
      recording_session = user.workspaces.first.recording_sessions.create!(
        creator: user,
        title: "Guard cleanup",
        transformer_handle: "default",
        status: :completed,
        work_path: outside_path.to_s
      ) { |session| attach_sample_audio(session) }

      recording_session.destroy!

      assert Dir.exist?(outside_path)
      assert outside_path.join("keep.txt").exist?
    end
  end
end

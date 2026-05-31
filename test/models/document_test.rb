require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "belongs to workspace and recording session" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    document = workspace.documents.create!(
      recording_session: recording_session,
      transformer_handle: "default",
      title: "Session",
      content: "# Document",
      generated_at: Time.current
    )

    assert_equal workspace, document.workspace
    assert_equal recording_session, document.recording_session
  end
end

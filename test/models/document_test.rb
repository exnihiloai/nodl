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

  test "local_generated_at renders in the recording's captured zone" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Session",
      transformer_handle: "default",
      time_zone: "Europe/Vienna"
    ) { |session| attach_sample_audio(session) }

    document = workspace.documents.create!(
      recording_session: recording_session,
      transformer_handle: "default",
      title: "Session",
      content: "# Document",
      generated_at: Time.utc(2026, 6, 8, 19, 0)
    )

    assert_equal "21:00 CEST", document.local_generated_at.strftime("%H:%M %Z")
  end

  test "local_generated_at falls back to the default zone without a captured zone" do
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
      generated_at: Time.utc(2026, 6, 8, 19, 0)
    )

    assert_equal document.generated_at, document.local_generated_at
  end
end

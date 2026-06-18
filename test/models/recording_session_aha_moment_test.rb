require "test_helper"

# Broadcast wiring for the trial aha-moment celebration. Eligibility and the
# time-saved math live in TrialAhaMomentTest; here we assert mark_completed!
# delegates to the service so the celebration reaches (or skips) the dashboard.
class RecordingSessionAhaMomentTest < ActiveSupport::TestCase
  test "completed first trial recording broadcasts the aha moment celebration" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Aha moment broadcast"
    )
    workspace.association(:current_entitlement).reset
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "First trial recording",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    Turbo::StreamsChannel.stubs(:broadcast_replace_to)
    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      [ workspace, :dashboard ],
      target: "aha_moment_slot",
      partial: "dashboard/aha_moment",
      locals: has_entries(recording_session: recording_session)
    )

    recording_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/session",
      audio_duration: 30
    )
  end

  test "completed non-trial recording does not broadcast the aha moment" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Private access recording",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    Turbo::StreamsChannel.stubs(:broadcast_replace_to)
    Turbo::StreamsChannel.expects(:broadcast_append_to).never

    recording_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/session",
      audio_duration: 30
    )
  end
end

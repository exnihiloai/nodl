require "application_js_system_test_case"

class AhaMomentJsTest < ApplicationJsSystemTestCase
  test "celebration modal appears when a trial recording completes on the dashboard" do
    email = unique_email("aha-moment")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Aha moment system test"
    )
    workspace.association(:current_entitlement).reset

    login_via_ui(email: email, password: "Valid123")
    assert_selector "#aha_moment_slot", visible: :all

    # Simulate the background job finishing: completing the recording broadcasts
    # the celebration over the dashboard stream the browser is subscribed to.
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "First trial recording",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.update_columns(
      processing_started_at: 12.seconds.ago,
      processing_completed_at: Time.current
    )
    recording_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/session",
      audio_duration: 600
    )

    assert_selector "[data-testid='aha-moment'][open]"
    assert_text "Done!"
    assert_selector "[data-testid='aha-moment-message']", text: "saved you about 1 hour"

    click_button "Keep going"

    assert_no_selector "[data-testid='aha-moment']"
  end

  test "no celebration for a non-trial workspace" do
    email = unique_email("aha-moment-manual")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first

    login_via_ui(email: email, password: "Valid123")

    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Private access recording",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/session",
      audio_duration: 600
    )

    assert_no_selector "[data-testid='aha-moment']"
  end
end

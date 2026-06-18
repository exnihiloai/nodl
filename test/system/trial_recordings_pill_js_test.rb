require "application_js_system_test_case"

class TrialRecordingsPillJsTest < ApplicationJsSystemTestCase
  test "pill appears and updates live as trial recordings complete" do
    email = unique_email("trial-pill")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)

    login_via_ui(email: email, password: "Valid123")

    # Fresh trial: no recordings yet, so no pill.
    assert_no_selector "[data-testid='trial-recordings-pill']"

    complete_recording(user, workspace, title: "First")
    assert_selector "[data-testid='trial-recordings-pill']", text: "2 of 3 free recordings left"

    complete_recording(user, workspace, title: "Second")
    assert_selector "[data-testid='trial-recordings-pill']", text: "1 of 3 free recordings left"
  end

  test "no pill for a non-trial workspace" do
    email = unique_email("manual-pill")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first

    login_via_ui(email: email, password: "Valid123")

    complete_recording(user, workspace, title: "Recording")

    assert_no_selector "[data-testid='trial-recordings-pill']"
  end

  private

  def grant_trial!(workspace)
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Trial pill system test"
    )
    workspace.association(:current_entitlement).reset
  end

  def complete_recording(user, workspace, title:)
    session = workspace.recording_sessions.create!(
      creator: user,
      title: title,
      transformer_handle: "default"
    ) { |s| attach_sample_audio(s) }
    session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/session"
    )
  end
end

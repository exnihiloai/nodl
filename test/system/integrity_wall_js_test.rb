require "application_js_system_test_case"

class IntegrityWallJsTest < ApplicationJsSystemTestCase
  test "activate button opens the Business upgrade wall for trial users" do
    email = unique_email("iwall")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    recording = create_recording(user, workspace)

    login_via_ui(email: email, password: "Valid123")
    visit recording_session_path(recording)

    find("[data-testid='integrity-status'] [data-disclosure-target='trigger']").click
    assert_selector "[data-testid='integrity-activate-button']"
    assert_no_selector "[data-testid='integrity-wall-modal'][open]"

    find("[data-testid='integrity-activate-button']").click

    assert_selector "[data-testid='integrity-wall-modal'][open]"
    assert_text "trusted timestamp"
    assert_selector "[data-testid='integrity-wall-upgrade-button']", text: "Upgrade to Business"
    assert_selector "[data-testid='integrity-wall-benefits']"

    find("[data-testid='integrity-wall-dismiss']").click
    assert_no_selector "[data-testid='integrity-wall-modal'][open]"
  end

  test "learn more link is present and navigates to the help page" do
    email = unique_email("iwall-learn")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    recording = create_recording(user, workspace)

    login_via_ui(email: email, password: "Valid123")
    visit recording_session_path(recording)

    find("[data-testid='integrity-status'] [data-disclosure-target='trigger']").click
    find("[data-testid='integrity-learn-more']").click

    assert_current_path integrity_proof_help_path
  end

  test "activate button and wall are absent for non-trial workspaces" do
    email = unique_email("iwall-nontrial")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    recording = create_recording(user, workspace)

    login_via_ui(email: email, password: "Valid123")
    visit recording_session_path(recording)

    find("[data-testid='integrity-status'] [data-disclosure-target='trigger']").click
    assert_no_selector "[data-testid='integrity-activate-button']"
    assert_no_selector "[data-testid='integrity-wall-modal']"
    assert_selector "[data-testid='integrity-learn-more']"
  end

  private

  def grant_trial!(workspace)
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Integrity wall system test"
    )
    workspace.association(:current_entitlement).reset
  end

  def create_recording(user, workspace)
    workspace.recording_sessions.create!(
      creator: user,
      title: "Test Recording",
      transformer_handle: "default",
      status: :completed,
      audio_duration: 30
    ) { |s| attach_sample_audio(s) }
  end
end

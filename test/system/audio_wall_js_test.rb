require "application_js_system_test_case"

class AudioWallJsTest < ApplicationJsSystemTestCase
  test "wall opens on reach-forward when trial audio download limit is reached" do
    email = unique_email("awall")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    recording = create_recording(user, workspace)
    record_download!(user, workspace, recording)

    login_via_ui(email: email, password: "Valid123")
    visit recording_session_path(recording)

    assert_selector "[data-testid='audio-actions-menu']"
    assert_no_selector "[data-testid='audio-wall-modal'][open]"

    find("[data-testid='audio-actions-menu-button']").click
    find("[data-testid='download-original-audio']").click

    assert_selector "[data-testid='audio-wall-modal'][open]"
    assert_text "whenever you need it"
    assert_selector "[data-testid='audio-wall-upgrade-button']", text: "Upgrade to Starter"
    assert_selector "[data-testid='audio-wall-benefits']"

    find("[data-testid='audio-wall-dismiss']").click
    assert_no_selector "[data-testid='audio-wall-modal'][open]"
  end

  test "download link works normally when audio download limit has not been reached" do
    email = unique_email("awall-free")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    recording = create_recording(user, workspace)

    login_via_ui(email: email, password: "Valid123")
    visit recording_session_path(recording)

    assert_no_selector "[data-controller='audio-wall']"
    assert_no_selector "[data-testid='audio-wall-modal']"
  end

  private

  def grant_trial!(workspace)
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Audio wall system test"
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

  def record_download!(user, workspace, recording)
    UsageRecorder.record!(
      workspace: workspace,
      user: user,
      event_kind: "original_audio_downloaded",
      subject: recording
    )
  end
end

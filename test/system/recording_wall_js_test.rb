require "application_js_system_test_case"

class RecordingWallJsTest < ApplicationJsSystemTestCase
  test "wall opens on the reach-forward when trial recordings are used up" do
    email = unique_email("wall")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    3.times { |i| complete_recording(user, workspace, title: "Document #{i}") }

    login_via_ui(email: email, password: "Valid123")

    # Limit reached: record/upload buttons are present but the modal is closed.
    assert_selector "[data-testid='recording-limit-reached']"
    assert_no_selector "[data-testid='recording-wall-modal'][open]"

    # The reach-forward opens the wall instead of starting a capture.
    find("[data-testid='record-button']").click

    assert_selector "[data-testid='recording-wall-modal'][open]"
    assert_text "into documents. Keep going"
    assert_selector "[data-testid='wall-upgrade-button']", text: "Upgrade to Starter"
    assert_selector "[data-testid='wall-see-plans-button']", text: "See plans"
    assert_selector "[data-testid='recording-wall-documents']", text: "Document 0"

    find("[data-testid='wall-dismiss']").click
    assert_no_selector "[data-testid='recording-wall-modal'][open]"
  end

  test "hero swaps to the wall live after the third recording completes" do
    email = unique_email("wall-live")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    2.times { |i| complete_recording(user, workspace, title: "Earlier #{i}") }

    login_via_ui(email: email, password: "Valid123")

    # Under the limit: the real recording form is shown, no wall.
    assert_no_selector "[data-testid='recording-limit-reached']"

    # Completing the third recording swaps the hero to the wall without a reload.
    complete_recording(user, workspace, title: "Third")

    assert_selector "[data-testid='recording-limit-reached']"
    find("[data-testid='record-button']").click
    assert_selector "[data-testid='recording-wall-modal'][open]"
  end

  private

  def grant_trial!(workspace)
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Recording wall system test"
    )
    workspace.association(:current_entitlement).reset
  end

  def complete_recording(user, workspace, title:)
    session = workspace.recording_sessions.create!(
      creator: user,
      title: title,
      transformer_handle: "default",
      audio_duration: 30
    ) { |s| attach_sample_audio(s) }
    session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# #{title}",
      work_path: "/tmp/session",
      audio_duration: 30
    )
  end
end

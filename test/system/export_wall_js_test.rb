require "application_js_system_test_case"

class ExportWallJsTest < ApplicationJsSystemTestCase
  test "wall opens on reach-forward when trial export limit is reached" do
    email = unique_email("ewall")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    document = create_document(user, workspace)
    record_export!(user, workspace, document)

    login_via_ui(email: email, password: "Valid123")
    visit document_path(document)

    # Download menu is present but modal is closed.
    assert_selector "[data-testid='download-menu']"
    assert_no_selector "[data-testid='export-wall-modal'][open]"

    find("[data-testid='download-menu']").click
    find("[data-testid='download-pdf']").click

    assert_selector "[data-testid='export-wall-modal'][open]"
    assert_text "Every time"
    assert_selector "[data-testid='export-wall-upgrade-button']", text: "Upgrade to Starter"
    assert_selector "[data-testid='export-wall-formats']", text: "PDF"

    find("[data-testid='export-wall-dismiss']").click
    assert_no_selector "[data-testid='export-wall-modal'][open]"
  end

  test "wall also opens when clicking Word or Markdown format links" do
    email = unique_email("ewall-fmt")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    document = create_document(user, workspace)
    record_export!(user, workspace, document)

    login_via_ui(email: email, password: "Valid123")
    visit document_path(document)

    find("[data-testid='download-menu']").click
    find("[data-testid='download-docx']").click
    assert_selector "[data-testid='export-wall-modal'][open]"
  end

  test "download links work normally when export limit has not been reached" do
    email = unique_email("ewall-free")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    document = create_document(user, workspace)

    login_via_ui(email: email, password: "Valid123")
    visit document_path(document)

    assert_no_selector "[data-controller='export-wall']"
    find("[data-testid='download-menu']").click
    assert_selector "[data-testid='download-pdf']"
    assert_no_selector "[data-testid='export-wall-modal']"
  end

  private

  def grant_trial!(workspace)
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Export wall system test"
    )
    workspace.association(:current_entitlement).reset
  end

  def create_document(user, workspace)
    session = workspace.recording_sessions.create!(
      creator: user,
      title: "Test Doc",
      transformer_handle: "default",
      status: :completed,
      audio_duration: 30
    ) { |s| attach_sample_audio(s) }
    session.create_document!(
      workspace: workspace,
      transformer_handle: "default",
      title: "Test Doc",
      content: "# Test",
      generated_at: Time.current
    )
  end

  def record_export!(user, workspace, document)
    UsageRecorder.record!(
      workspace: workspace,
      user: user,
      event_kind: "document_exported",
      subject: document,
      metadata: { format: "pdf" }
    )
  end
end

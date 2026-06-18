require "test_helper"

class DocumentsControllerExportWallTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    grant_trial!
    post login_path, params: { email: @user.email, password: "Valid123" }
    @document = create_document
  end

  test "export_wall is false before the free export is used" do
    get document_path(@document)
    assert_response :success
    assert_equal false, assigns(:export_wall)
  end

  test "export_wall is true once the free export is consumed" do
    record_export!
    get document_path(@document)
    assert_response :success
    assert_equal true, assigns(:export_wall)
  end

  test "export_wall is false for non-trial workspaces even after an export" do
    upgrade_to_manual_plan!
    record_export!
    get document_path(@document)
    assert_response :success
    assert_equal false, assigns(:export_wall)
  end

  private

  def grant_trial!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Export wall controller test"
    )
    @workspace.association(:current_entitlement).reset
  end

  def upgrade_to_manual_plan!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "manual",
      source: "manual",
      status: "active",
      reason: "Upgrade for export wall test"
    )
    @workspace.association(:current_entitlement).reset
  end

  def create_document
    session = @workspace.recording_sessions.create!(
      creator: @user,
      title: "Test",
      transformer_handle: "default",
      status: :completed,
      audio_duration: 30
    ) { |s| attach_sample_audio(s) }
    session.create_document!(
      workspace: @workspace,
      transformer_handle: "default",
      title: "Test",
      content: "# Test",
      generated_at: Time.current
    )
  end

  def record_export!
    UsageRecorder.record!(
      workspace: @workspace,
      user: @user,
      event_kind: "document_exported",
      subject: @document,
      metadata: { format: "pdf" }
    )
  end
end

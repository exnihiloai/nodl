require "test_helper"

class RecordingSessionsControllerIntegrityWallTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    post login_path, params: { email: @user.email, password: "Valid123" }
    @session = create_recording_session
  end

  test "integrity_wall is true for trial workspaces" do
    grant_trial!
    get recording_session_path(@session)
    assert_response :success
    assert_equal true, assigns(:integrity_wall)
  end

  test "integrity_wall is false for non-trial workspaces" do
    get recording_session_path(@session)
    assert_response :success
    assert_equal false, assigns(:integrity_wall)
  end

  private

  def grant_trial!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Integrity wall controller test"
    )
    @workspace.association(:current_entitlement).reset
  end

  def create_recording_session
    @workspace.recording_sessions.create!(
      creator: @user,
      title: "Test",
      transformer_handle: "default",
      status: :completed,
      audio_duration: 30
    ) { |s| attach_sample_audio(s) }
  end
end

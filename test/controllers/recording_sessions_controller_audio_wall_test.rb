require "test_helper"

class RecordingSessionsControllerAudioWallTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    grant_trial!
    post login_path, params: { email: @user.email, password: "Valid123" }
    @session = create_recording_session
  end

  test "audio_wall is false before the free download is used" do
    get recording_session_path(@session)
    assert_response :success
    refute_includes response.body, 'data-testid="audio-wall-modal"'
  end

  test "audio_wall is true once the free download is consumed" do
    record_download!
    get recording_session_path(@session)
    assert_response :success
    assert_includes response.body, 'data-testid="audio-wall-modal"'
  end

  test "audio_wall is false for non-trial workspaces even after a download" do
    upgrade_to_manual_plan!
    record_download!
    get recording_session_path(@session)
    assert_response :success
    refute_includes response.body, 'data-testid="audio-wall-modal"'
  end

  private

  def grant_trial!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Audio wall controller test"
    )
    @workspace.association(:current_entitlement).reset
  end

  def upgrade_to_manual_plan!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "manual",
      source: "manual",
      status: "active",
      reason: "Upgrade for audio wall test"
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

  def record_download!
    UsageRecorder.record!(
      workspace: @workspace,
      user: @user,
      event_kind: "original_audio_downloaded",
      subject: @session
    )
  end
end

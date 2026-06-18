require "test_helper"

class TrialRecordingsBadgeTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    grant_trial!
  end

  test "hidden on a fresh trial before the first recording" do
    badge = TrialRecordingsBadge.new(@workspace)

    assert_not badge.visible?
    assert_equal 0, badge.used
    assert_equal 3, badge.limit
    assert_equal 3, badge.remaining
  end

  test "visible after the first recording with remaining count" do
    create_recordings(1)
    badge = TrialRecordingsBadge.new(@workspace)

    assert badge.visible?
    assert_equal 1, badge.used
    assert_equal 2, badge.remaining
  end

  test "remaining decreases as recordings are used" do
    create_recordings(2)

    assert_equal 1, TrialRecordingsBadge.new(@workspace).remaining
  end

  test "remaining never drops below zero at the limit" do
    create_recordings(3)
    badge = TrialRecordingsBadge.new(@workspace)

    assert badge.visible?
    assert_equal 3, badge.used
    assert_equal 0, badge.remaining
  end

  test "deleting a recording does not free up the count" do
    recordings = create_recordings(2)
    recordings.first.destroy!

    assert_equal 2, TrialRecordingsBadge.new(@workspace.reload).used
  end

  test "hidden off the free trial even with recordings" do
    create_recordings(1)
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "manual",
      source: "manual",
      status: "active",
      reason: "Private access"
    )
    @workspace.association(:current_entitlement).reset

    assert_not TrialRecordingsBadge.new(@workspace).visible?
  end

  test "broadcasts the pill replacement on the free trial" do
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      [ @workspace, :dashboard ],
      target: "trial_recordings_pill",
      partial: "dashboard/trial_recordings_pill",
      locals: has_key(:badge)
    )

    TrialRecordingsBadge.new(@workspace).broadcast!
  end

  test "does not broadcast off the free trial" do
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "manual",
      source: "manual",
      status: "active",
      reason: "Private access"
    )
    @workspace.association(:current_entitlement).reset

    Turbo::StreamsChannel.expects(:broadcast_replace_to).never

    TrialRecordingsBadge.new(@workspace).broadcast!
  end

  private

  def grant_trial!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Trial recordings pill test"
    )
    @workspace.association(:current_entitlement).reset
  end

  def create_recordings(count)
    count.times.map do |index|
      @workspace.recording_sessions.create!(
        creator: @user,
        title: "Recording #{index}",
        transformer_handle: "default",
        status: :completed
      ) { |session| attach_sample_audio(session) }
    end
  end
end

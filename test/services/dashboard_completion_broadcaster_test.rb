require "test_helper"

class DashboardCompletionBroadcasterTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    grant_trial!
  end

  test "swaps the record hero to the wall once the recording limit is reached" do
    session = create_recordings(3).last

    TrialRecordingsBadge.any_instance.expects(:broadcast!)
    TrialAhaMoment.any_instance.expects(:broadcast!)
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      [ @workspace, :dashboard ],
      target: "dashboard_record_hero",
      partial: "dashboard/record_hero",
      locals: has_entries(recording_limit_reached: true)
    )

    DashboardCompletionBroadcaster.new(session).call
  end

  test "does not swap the record hero while recordings remain" do
    session = create_recordings(1).last

    TrialRecordingsBadge.any_instance.expects(:broadcast!)
    TrialAhaMoment.any_instance.expects(:broadcast!)
    Turbo::StreamsChannel.expects(:broadcast_replace_to).never

    DashboardCompletionBroadcaster.new(session).call
  end

  private

  def grant_trial!
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Wall broadcaster test"
    )
    @workspace.association(:current_entitlement).reset
  end

  def create_recordings(count)
    count.times.map do |index|
      @workspace.recording_sessions.create!(
        creator: @user,
        title: "Recording #{index}",
        transformer_handle: "default",
        status: :completed,
        audio_duration: 30
      ) { |session| attach_sample_audio(session) }
    end
  end
end

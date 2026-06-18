require "test_helper"

class TrialAhaMomentTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Aha moment test"
    )
    @workspace.association(:current_entitlement).reset
  end

  test "first trial recording is eligible even when short" do
    session = completed_recording(audio_duration: 30)

    assert TrialAhaMoment.new(session).eligible?
  end

  test "later short recording is not eligible" do
    completed_recording(audio_duration: 30)
    second = completed_recording(audio_duration: 45)

    assert_not TrialAhaMoment.new(second).eligible?
  end

  test "later recording longer than two minutes is eligible" do
    completed_recording(audio_duration: 30)
    second = completed_recording(audio_duration: 200)

    assert TrialAhaMoment.new(second).eligible?
  end

  test "not eligible off the free trial" do
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "manual",
      source: "manual",
      status: "active",
      reason: "Private access"
    )
    @workspace.association(:current_entitlement).reset
    session = completed_recording(audio_duration: 30)

    assert_not TrialAhaMoment.new(session).eligible?
  end

  test "not eligible until the recording is completed" do
    session = @workspace.recording_sessions.create!(
      creator: @user,
      title: "In progress",
      transformer_handle: "default",
      status: :processing
    ) { |s| attach_sample_audio(s) }

    assert_not TrialAhaMoment.new(session).eligible?
  end

  test "conversion seconds reflects processing wall-clock time, floored at one" do
    session = completed_recording(audio_duration: 30)
    session.update!(
      processing_started_at: Time.utc(2026, 6, 18, 12, 0, 0),
      processing_completed_at: Time.utc(2026, 6, 18, 12, 0, 18)
    )

    assert_equal 18, TrialAhaMoment.new(session).conversion_seconds

    session.update!(processing_completed_at: session.processing_started_at)
    assert_equal 1, TrialAhaMoment.new(session).conversion_seconds
  end

  test "time saved interpolates to the spec anchor points" do
    {
      60 => 600,      # 1 min audio  -> ~10 min effort
      600 => 3600,    # 10 min audio -> ~1 hour effort
      1800 => 9000,   # 30 min audio -> ~2.5 hours effort
      3600 => 18000   # 60 min audio -> ~5 hours effort
    }.each do |audio_seconds, expected_effort|
      session = built_recording(audio_duration: audio_seconds)
      assert_in_delta expected_effort, TrialAhaMoment.new(session).time_saved_seconds, 0.01,
        "expected #{audio_seconds}s of audio to map to #{expected_effort}s of effort"
    end
  end

  test "time saved interpolates between anchors" do
    # Halfway between (60, 600) and (600, 3600): audio 330s -> effort 2100s.
    session = built_recording(audio_duration: 330)

    assert_in_delta 2100, TrialAhaMoment.new(session).time_saved_seconds, 0.01
  end

  test "time saved extrapolates beyond the final anchor" do
    # Past 3600s the last segment's slope (5x) continues: 4200s -> 21000s.
    session = built_recording(audio_duration: 4200)

    assert_in_delta 21000, TrialAhaMoment.new(session).time_saved_seconds, 0.01
  end

  test "time saved is zero without a usable duration" do
    session = built_recording(audio_duration: 0)

    assert_equal 0.0, TrialAhaMoment.new(session).time_saved_seconds
  end

  private

  def completed_recording(audio_duration:)
    @workspace.recording_sessions.create!(
      creator: @user,
      title: "Recording",
      transformer_handle: "default",
      status: :completed,
      audio_duration: audio_duration
    ) { |s| attach_sample_audio(s) }
  end

  # Unsaved record for exercising the time-saved math without consuming a trial
  # recording slot. No usable audio attachment, so audio_duration is the only
  # duration source.
  def built_recording(audio_duration:)
    @workspace.recording_sessions.build(
      creator: @user,
      title: "Recording",
      transformer_handle: "default",
      status: :completed,
      audio_duration: audio_duration
    )
  end
end

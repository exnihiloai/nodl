require "test_helper"

class SendDailyReminderPushJobTest < ActiveJob::TestCase
  setup do
    @user = create_user_with_workspace
    @user.update!(
      daily_reminder_enabled: true,
      time_zone: "UTC",
      daily_reminder_at: "21:00",
      preferred_language: "en"
    )
    @subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.test/device/#{SecureRandom.hex(4)}",
      p256dh_key: "p256dh",
      auth_key: "auth"
    )
  end

  teardown do
    @user.created_recording_sessions.destroy_all
    @user&.destroy
  end

  test "sends push notification and marks reminder as sent" do
    WebPush.expects(:payload_send).once.returns(true)

    SendDailyReminderPushJob.perform_now(@user.id)

    assert_equal Date.current, @user.reload.daily_reminder_last_sent_on
  end

  test "removes expired subscriptions" do
    response = Struct.new(:code, :body).new("410", "Gone")
    WebPush.expects(:payload_send).raises(WebPush::ExpiredSubscription.new(response, "push.example.test"))

    assert_difference -> { PushSubscription.count }, -1 do
      SendDailyReminderPushJob.perform_now(@user.id)
    end
  end

  test "skips when user already nodled after dispatch" do
    workspace = @user.workspaces.first
    workspace.recording_sessions.create!(
      creator: @user,
      title: "Done",
      transformer_handle: "default",
      status: :completed,
      time_zone: "UTC"
    ) { |recording| attach_sample_audio(recording) }

    WebPush.expects(:payload_send).never

    SendDailyReminderPushJob.perform_now(@user.id)

    assert_nil @user.reload.daily_reminder_last_sent_on
  end

  test "skips when reminder was already sent after dispatch" do
    @user.update!(daily_reminder_last_sent_on: Date.current)
    WebPush.expects(:payload_send).never

    SendDailyReminderPushJob.perform_now(@user.id)

    assert_equal Date.current, @user.reload.daily_reminder_last_sent_on
  end

  test "skips when subscriptions were removed after dispatch" do
    @user.push_subscriptions.destroy_all
    WebPush.expects(:payload_send).never

    SendDailyReminderPushJob.perform_now(@user.id)

    assert_nil @user.reload.daily_reminder_last_sent_on
  end
end

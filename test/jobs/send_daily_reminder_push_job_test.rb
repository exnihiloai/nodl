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
end

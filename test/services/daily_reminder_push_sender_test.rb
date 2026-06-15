require "test_helper"

class DailyReminderPushSenderTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @user.update!(
      daily_reminder_enabled: true,
      time_zone: "UTC",
      daily_reminder_at: "21:00",
      daily_reminder_message: "Time to nodl",
      preferred_language: "en"
    )
  end

  teardown do
    @user&.destroy
  end

  test "uses reminder message as notification title and dashboard click target" do
    create_subscription
    payload = nil

    WebPush.expects(:payload_send).with do |args|
      payload = JSON.parse(args.fetch(:message))
      true
    end.returns(true)

    assert DailyReminderPushSender.call(@user)
    assert_equal "Time to nodl", payload.fetch("title")
    assert_nil payload.dig("options", "body")
    assert_equal "/dashboard", payload.dig("options", "data", "path")
  end

  test "marks reminder sent when at least one subscription succeeds" do
    create_subscription(endpoint: "https://push.example.test/device/success")
    create_subscription(endpoint: "https://push.example.test/device/failure")

    WebPush.expects(:payload_send).twice.then.returns(true).then.raises(response_error("500"))

    assert DailyReminderPushSender.call(@user)
    assert_equal Date.current, @user.reload.daily_reminder_last_sent_on
  end

  test "does not mark sent when every subscription fails" do
    create_subscription
    WebPush.expects(:payload_send).raises(response_error("500"))

    assert_not DailyReminderPushSender.call(@user)
    assert_nil @user.reload.daily_reminder_last_sent_on
  end

  test "removes expired subscriptions" do
    create_subscription
    WebPush.expects(:payload_send).raises(response_error("410"))

    assert_difference -> { PushSubscription.count }, -1 do
      assert_not DailyReminderPushSender.call(@user)
    end
  end

  private

  def create_subscription(endpoint: "https://push.example.test/device/#{SecureRandom.hex(4)}")
    @user.push_subscriptions.create!(
      endpoint: endpoint,
      p256dh_key: "p256dh",
      auth_key: "auth"
    )
  end

  def response_error(code)
    response = Struct.new(:code, :body).new(code, "Push error")
    WebPush::ResponseError.new(response, "push.example.test")
  end
end

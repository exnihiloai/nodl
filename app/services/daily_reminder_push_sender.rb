class DailyReminderPushSender
  EXPIRED_STATUS_CODES = [ 404, 410 ].freeze

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return false unless WebPushConfig.configured?
    return false if @user.push_subscriptions.none?

    sent_any = false

    @user.push_subscriptions.find_each do |subscription|
      if deliver(subscription)
        sent_any = true
      end
    end

    if sent_any
      mark_sent_today!
      true
    else
      false
    end
  end

  private

  def deliver(subscription)
    WebPush.payload_send(
      message: payload.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: WebPushConfig.vapid_options
    )
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::ResponseError => error
    subscription.destroy! if expired_subscription?(error)
    false
  end

  def expired_subscription?(error)
    return true if error.is_a?(WebPush::ExpiredSubscription) || error.is_a?(WebPush::InvalidSubscription)

    error.is_a?(WebPush::ResponseError) && EXPIRED_STATUS_CODES.include?(error.response&.code.to_i)
  end

  def payload
    {
      title: "Nodl",
      options: {
        body: @user.daily_reminder_message_text,
        data: { path: "/dashboard" }
      }
    }
  end

  def mark_sent_today!
    tz = ActiveSupport::TimeZone[@user.time_zone]
    sent_on = tz ? tz.now.to_date : Date.current
    @user.update_column(:daily_reminder_last_sent_on, sent_on)
  end
end

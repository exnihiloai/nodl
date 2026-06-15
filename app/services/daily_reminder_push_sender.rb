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
    instrument_delivery(subscription, success: true)
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::ResponseError => error
    expired = expired_subscription?(error)
    instrument_delivery(subscription, success: false, error: error, expired: expired)
    subscription.destroy! if expired
    false
  end

  def expired_subscription?(error)
    return true if error.is_a?(WebPush::ExpiredSubscription) || error.is_a?(WebPush::InvalidSubscription)

    error.is_a?(WebPush::ResponseError) && EXPIRED_STATUS_CODES.include?(error.response&.code.to_i)
  end

  def payload
    # iOS PWAs always render "from {app name}" under the title (manifest short_name).
    # Use the reminder text as the title so users see the message, not a duplicate "Nodl".
    {
      title: @user.daily_reminder_message_text,
      options: {
        data: { path: "/dashboard" }
      }
    }
  end

  def mark_sent_today!
    tz = ActiveSupport::TimeZone[@user.time_zone]
    sent_on = tz ? tz.now.to_date : Date.current
    @user.update_column(:daily_reminder_last_sent_on, sent_on)
  end

  def instrument_delivery(subscription, success:, error: nil, expired: false)
    ActiveSupport::Notifications.instrument(
      "daily_reminders.send",
      user_id: @user.id,
      subscription_id: subscription.id,
      endpoint_host: endpoint_host(subscription.endpoint),
      success: success,
      expired: expired,
      error_class: error&.class&.name,
      status: response_status(error)
    )
  end

  def endpoint_host(endpoint)
    URI.parse(endpoint).host
  rescue URI::InvalidURIError
    nil
  end

  def response_status(error)
    error.respond_to?(:response) ? error.response&.code&.to_i : nil
  end
end

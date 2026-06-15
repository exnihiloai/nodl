class SendDailyReminderPushJob < ApplicationJob
  queue_as :default

  def perform(user_id, sent_at_iso8601 = nil)
    user = User.find_by(id: user_id)
    skip_reason = skip_reason(user, sent_at_iso8601)
    if skip_reason
      instrument_skip(user_id, skip_reason)
      return
    end

    DailyReminderPushSender.call(user)
  end

  private

  def skip_reason(user, sent_at_iso8601)
    return :missing_user unless user
    return :inactive unless user.active?
    return :disabled unless user.daily_reminder_enabled?
    return :no_subscriptions if user.push_subscriptions.none?
    return :nodled_today if user.nodled_today?
    return :already_sent if user.reminder_already_sent_today?(now: sent_at(sent_at_iso8601))

    nil
  end

  def sent_at(sent_at_iso8601)
    Time.zone.parse(sent_at_iso8601.to_s) || Time.current
  rescue ArgumentError, TypeError
    Time.current
  end

  def instrument_skip(user_id, reason)
    ActiveSupport::Notifications.instrument(
      "daily_reminders.send_skipped",
      user_id: user_id,
      reason: reason
    )
  end
end

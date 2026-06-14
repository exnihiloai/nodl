class DispatchDailyRemindersJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    User.active_only
      .where(daily_reminder_enabled: true)
      .where.not(time_zone: nil)
      .find_each do |user|
        next unless user.reminder_due_at?(now: now)
        next if user.nodled_today?
        next if user.reminder_already_sent_today?(now: now)
        next if user.push_subscriptions.none?

        SendDailyReminderPushJob.perform_later(user.id, now.iso8601)
      end
  end
end

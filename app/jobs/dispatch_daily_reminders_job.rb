class DispatchDailyRemindersJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    users_scanned = 0
    jobs_enqueued = 0
    skipped = Hash.new(0)

    User.active_only
      .where(daily_reminder_enabled: true)
      .where.not(time_zone: nil)
      .find_each do |user|
        users_scanned += 1

        unless user.reminder_due_at?(now: now)
          skipped[:not_due] += 1
          next
        end

        if user.nodled_today?
          skipped[:nodled_today] += 1
          next
        end

        if user.reminder_already_sent_today?(now: now)
          skipped[:already_sent] += 1
          next
        end

        if user.push_subscriptions.none?
          skipped[:no_subscriptions] += 1
          next
        end

        SendDailyReminderPushJob.perform_later(user.id, now.iso8601)
        jobs_enqueued += 1
      end

    ActiveSupport::Notifications.instrument(
      "daily_reminders.dispatch",
      users_scanned: users_scanned,
      jobs_enqueued: jobs_enqueued,
      skipped: skipped
    )
  end
end

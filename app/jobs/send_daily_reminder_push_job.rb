class SendDailyReminderPushJob < ApplicationJob
  queue_as :default

  def perform(user_id, _sent_at_iso8601 = nil)
    user = User.find_by(id: user_id)
    return unless user&.daily_reminder_enabled?

    DailyReminderPushSender.call(user)
  end
end

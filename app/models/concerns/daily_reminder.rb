module DailyReminder
  extend ActiveSupport::Concern

  included do
    normalizes :time_zone, with: ->(value) {
      zone = value.to_s.strip.presence
      zone if zone && ActiveSupport::TimeZone[zone]
    }

    validates :daily_reminder_enabled, inclusion: { in: [ true, false ] }
    validates :daily_reminder_message, length: { maximum: 30 }, allow_nil: true
    validate :daily_reminder_settings_when_enabled
  end

  def daily_reminder_message_text
    daily_reminder_message.presence || I18n.t("settings.daily_reminder.default_message", locale: preferred_language)
  end

  def nodled_today?
    return false if time_zone.blank?

    tz = ActiveSupport::TimeZone[time_zone]
    return false unless tz

    today = tz.now.to_date
    range = tz.local(today.year, today.month, today.day).all_day
    created_recording_sessions.finalized.exists?(created_at: range)
  end

  def reminder_due_at?(now: Time.current)
    return false unless daily_reminder_enabled?
    return false if time_zone.blank? || daily_reminder_at.blank?

    tz = ActiveSupport::TimeZone[time_zone]
    return false unless tz

    local_now = now.in_time_zone(tz)
    local_now.strftime("%H:%M") == daily_reminder_at.strftime("%H:%M")
  end

  def reminder_already_sent_today?(now: Time.current)
    return false if daily_reminder_last_sent_on.blank? || time_zone.blank?

    tz = ActiveSupport::TimeZone[time_zone]
    return false unless tz

    daily_reminder_last_sent_on == now.in_time_zone(tz).to_date
  end

  private

  def daily_reminder_settings_when_enabled
    return unless daily_reminder_enabled?

    errors.add(:time_zone, :blank) if time_zone.blank?
    errors.add(:daily_reminder_at, :blank) if daily_reminder_at.blank?
  end
end

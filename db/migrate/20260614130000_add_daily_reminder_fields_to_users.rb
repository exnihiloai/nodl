class AddDailyReminderFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string
    add_column :users, :daily_reminder_enabled, :boolean, default: false, null: false
    add_column :users, :daily_reminder_at, :time
    add_column :users, :daily_reminder_message, :string, limit: 30
    add_column :users, :daily_reminder_last_sent_on, :date
  end
end

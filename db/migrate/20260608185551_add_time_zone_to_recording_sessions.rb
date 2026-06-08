class AddTimeZoneToRecordingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_sessions, :time_zone, :string
  end
end

class ValidateUsageEventsUserForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :usage_events, :users
  end
end

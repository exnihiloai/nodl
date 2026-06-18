class AddUsagePeriodToEntitlements < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :workspace_entitlements, :usage_period_started_at, :datetime
    add_column :workspace_entitlements, :usage_period_ends_at, :datetime
    add_column :usage_events, :usage_period_started_at, :datetime
    add_column :usage_events, :usage_period_ends_at, :datetime

    add_index :workspace_entitlements, [ :usage_period_started_at, :usage_period_ends_at ], algorithm: :concurrently
  end
end

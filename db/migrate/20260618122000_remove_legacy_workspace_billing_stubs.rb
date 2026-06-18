class RemoveLegacyWorkspaceBillingStubs < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :workspaces, :subscription_status, :string
      remove_column :workspaces, :subscription_plan, :string
      remove_column :workspaces, :subscription_billing_cycle, :string
      remove_column :workspaces, :usage_limits, :jsonb
      remove_column :workspaces, :usage_consumption, :jsonb
    end
  end
end

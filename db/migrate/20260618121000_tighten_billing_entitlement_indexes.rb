class TightenBillingEntitlementIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :usage_events, :workspace_id
    remove_index :billing_plan_versions, :billing_plan_id

    remove_foreign_key :usage_events, :users
    add_foreign_key :usage_events, :users, on_delete: :nullify, validate: false
  end
end

class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :subscription_status, null: false, default: "inactive"
      t.string :subscription_plan, null: false, default: "free"
      t.string :subscription_billing_cycle, null: false, default: "monthly"
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.jsonb :usage_limits, null: false, default: {}
      t.jsonb :usage_consumption, null: false, default: {}

      t.timestamps
    end

    add_index :workspaces, :slug, unique: true
  end
end

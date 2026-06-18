class CreateBillingEntitlements < ActiveRecord::Migration[8.1]
  def up
    create_table :billing_plans do |t|
      t.string :code, null: false
      t.string :display_name, null: false
      t.boolean :stripe_required, null: false, default: false
      t.timestamps

      t.index :code, unique: true
    end

    create_table :billing_plan_versions do |t|
      t.references :billing_plan, null: false, foreign_key: true
      t.string :version_key, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :limits, null: false, default: {}
      t.string :stripe_price_id
      t.datetime :active_from
      t.datetime :retired_at
      t.timestamps

      t.index :version_key, unique: true
      t.index [ :billing_plan_id, :status ]
      t.index :stripe_price_id, unique: true, where: "stripe_price_id IS NOT NULL"
    end

    create_table :workspace_entitlements do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.references :billing_plan_version, null: false, foreign_key: true
      t.string :source, null: false
      t.string :status, null: false
      t.jsonb :limits_snapshot, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.datetime :trial_started_at
      t.datetime :trial_ends_at
      t.datetime :current_period_started_at
      t.datetime :current_period_ends_at
      t.datetime :grace_period_ends_at
      t.datetime :expires_at
      t.timestamps

      t.index :source
      t.index :status
      t.index :stripe_customer_id
      t.index :stripe_subscription_id, unique: true, where: "stripe_subscription_id IS NOT NULL"
    end

    create_table :usage_events do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :event_kind, null: false
      t.decimal :quantity, precision: 20, scale: 4, null: false, default: 1
      t.string :unit, null: false, default: "count"
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :billing_period_started_at
      t.datetime :billing_period_ends_at
      t.timestamps

      t.index [ :workspace_id, :event_kind, :occurred_at ]
      t.index [ :subject_type, :subject_id ]
    end

    create_table :stripe_webhook_events do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.datetime :processed_at, null: false
      t.timestamps

      t.index :stripe_event_id, unique: true
    end

    seed_catalog_and_grant_existing_workspaces
  end

  def down
    drop_table :stripe_webhook_events
    drop_table :usage_events
    drop_table :workspace_entitlements
    drop_table :billing_plan_versions
    drop_table :billing_plans
  end

  private

  def seed_catalog_and_grant_existing_workspaces
    return unless defined?(BillingCatalog)

    BillingCatalog.ensure!
    manual_version = BillingCatalog.active_version!("manual")

    Workspace.find_each do |workspace|
      WorkspaceEntitlement.find_or_create_by!(workspace:) do |entitlement|
        entitlement.billing_plan_version = manual_version
        entitlement.source = "manual"
        entitlement.status = "active"
        entitlement.limits_snapshot = manual_version.limits.deep_dup
        entitlement.metadata = { "reason" => "Existing workspace migrated to Private Access" }
      end
    end
  end
end

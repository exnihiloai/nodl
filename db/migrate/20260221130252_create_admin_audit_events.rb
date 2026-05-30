class CreateAdminAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_audit_events do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :acting_admin_id, null: false
      t.string :action, null: false
      t.jsonb :before_state
      t.jsonb :after_state

      t.timestamps
    end

    add_foreign_key :admin_audit_events, :users, column: :acting_admin_id
    add_index :admin_audit_events, :acting_admin_id
  end
end

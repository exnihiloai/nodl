class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.integer :role, null: false, default: 2

      t.timestamps
    end

    add_index :memberships, %i[user_id workspace_id], unique: true
  end
end

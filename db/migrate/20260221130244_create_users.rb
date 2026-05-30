class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :last_login_at
      t.string :preferred_language, null: false, default: "en"

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end

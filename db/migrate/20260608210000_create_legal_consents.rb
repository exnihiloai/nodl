class CreateLegalConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :legal_consents do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :document, null: false
      t.string :version, null: false
      t.datetime :accepted_at, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :legal_consents, [ :user_id, :document ]
  end
end

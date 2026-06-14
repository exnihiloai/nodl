class CreateRecordingIntegrityRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_integrity_records do |t|
      t.references :recording_session, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :hash_sha256, limit: 64, null: false
      t.string :hash_algorithm, limit: 20, null: false
      t.datetime :hashed_at, null: false
      t.string :tsa_status, limit: 30, null: false
      t.string :tsa_provider, limit: 80, null: false
      t.string :tsa_authority, limit: 255
      t.string :tsa_proof_format, limit: 50
      t.text :tsa_proof_blob
      t.datetime :tsa_timestamp
      t.string :tsa_error, limit: 500

      t.timestamps
    end

    add_index :recording_integrity_records, :tsa_status
  end
end

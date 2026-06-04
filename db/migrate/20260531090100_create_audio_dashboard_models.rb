class CreateAudioDashboardModels < ActiveRecord::Migration[8.1]
  def change
    create_table :transformer_profiles do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :handle, null: false
      t.string :name, null: false
      t.string :source_path, null: false
      t.boolean :default, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps

      t.index %i[workspace_id handle], unique: true
      t.index :workspace_id, unique: true, where: "\"default\" = TRUE", name: "index_transformer_profiles_one_default_per_workspace"
    end

    create_table :recording_sessions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.integer :status, null: false, default: 0
      t.integer :source_kind, null: false, default: 0
      t.string :transformer_handle, null: false, default: "default"
      t.text :transcript_text
      t.text :error_message
      t.string :work_path
      t.datetime :processing_started_at
      t.datetime :processing_completed_at

      t.timestamps

      t.index %i[workspace_id created_at]
      t.index %i[workspace_id status]
      t.index :transformer_handle
    end

    create_table :documents do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :recording_session, null: false, foreign_key: true
      t.string :transformer_handle, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.datetime :generated_at, null: false

      t.timestamps

      t.index %i[workspace_id generated_at]
      t.index %i[recording_session_id transformer_handle]
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO transformer_profiles
            (workspace_id, handle, name, source_path, "default", active, created_at, updated_at)
          SELECT
            id,
            'default',
            'Default Transformer',
            'transformers/default',
            TRUE,
            TRUE,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          FROM workspaces
        SQL
      end
    end
  end
end

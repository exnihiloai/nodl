class DropRedundantSingleColumnIndexes < ActiveRecord::Migration[8.1]
  # database_consistency's RedundantIndexChecker flagged these single-column
  # indexes as redundant: each is the leading column of an existing composite
  # index that already serves the same lookups. Drop them to remove the write
  # overhead and clear the baseline.
  #
  #   documents.workspace_id              <- index_documents_on_workspace_id_and_generated_at
  #   memberships.user_id                 <- index_memberships_on_user_id_and_workspace_id
  #   recording_sessions.workspace_id     <- index_recording_sessions_on_workspace_id_and_created_at
  #   transformer_profiles.workspace_id   <- index_transformer_profiles_on_workspace_id_and_handle
  #
  # (documents.recording_session_id is intentionally kept — it was converted to
  # a UNIQUE index in the preceding migration, so it is no longer redundant.)
  disable_ddl_transaction!

  def up
    remove_index :documents, :workspace_id,
                 name: "index_documents_on_workspace_id", algorithm: :concurrently
    remove_index :memberships, :user_id,
                 name: "index_memberships_on_user_id", algorithm: :concurrently
    remove_index :recording_sessions, :workspace_id,
                 name: "index_recording_sessions_on_workspace_id", algorithm: :concurrently
    remove_index :transformer_profiles, :workspace_id,
                 name: "index_transformer_profiles_on_workspace_id", algorithm: :concurrently
  end

  def down
    add_index :documents, :workspace_id,
              name: "index_documents_on_workspace_id", algorithm: :concurrently
    add_index :memberships, :user_id,
              name: "index_memberships_on_user_id", algorithm: :concurrently
    add_index :recording_sessions, :workspace_id,
              name: "index_recording_sessions_on_workspace_id", algorithm: :concurrently
    add_index :transformer_profiles, :workspace_id,
              name: "index_transformer_profiles_on_workspace_id", algorithm: :concurrently
  end
end

class AddUniqueIndexToDocumentsRecordingSession < ActiveRecord::Migration[8.1]
  # A recording session has_one :document, but the column only had a plain
  # (non-unique) index, so nothing at the DB level prevented two documents from
  # pointing at the same session. Replace it with a unique index so the
  # one-to-one is enforced by Postgres, not just the app-level transaction in
  # RecordingSession#mark_completed!.
  #
  # disable_ddl_transaction! so the index can be (re)built CONCURRENTLY without
  # taking a long lock on the documents table.
  disable_ddl_transaction!

  def up
    remove_index :documents, :recording_session_id,
                 name: "index_documents_on_recording_session_id", algorithm: :concurrently
    add_index :documents, :recording_session_id,
              unique: true, name: "index_documents_on_recording_session_id", algorithm: :concurrently
  end

  def down
    remove_index :documents, :recording_session_id,
                 name: "index_documents_on_recording_session_id", algorithm: :concurrently
    add_index :documents, :recording_session_id,
              name: "index_documents_on_recording_session_id", algorithm: :concurrently
  end
end

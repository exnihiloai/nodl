require "test_helper"

# Verifies tenant-scoped content columns are stored encrypted in PostgreSQL
# (Active Record Encryption) while reading back as plaintext through the model.
class EncryptionAtRestTest < ActiveSupport::TestCase
  test "sensitive columns are ciphertext at rest and decrypt transparently" do
    user = create_user_with_workspace(workspace_name: "Secret Org")
    workspace = user.workspaces.first

    assert_equal "Secret Org", workspace.name
    assert_encrypted_at_rest "workspaces", "name", workspace.id, "Secret Org"

    profile = workspace.transformer_profiles.first
    assert_encrypted_at_rest "transformer_profiles", "name", profile.id, profile.name
    assert_encrypted_at_rest "transformer_profiles", "instructions", profile.id, profile.instructions

    recording = workspace.recording_sessions.create!(
      creator: user,
      title: "Confidential client call",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    recording.update!(
      transcript_text: "the secret passphrase is hunter2",
      transcript_segments: [ { "start" => 0.0, "end" => 1.0, "text" => "secret words" } ]
    )

    assert_encrypted_at_rest "recording_sessions", "title", recording.id, "Confidential client call"
    assert_encrypted_at_rest "recording_sessions", "transcript_text", recording.id, "hunter2"
    assert_encrypted_at_rest "recording_sessions", "transcript_segments", recording.id, "secret words"
    # transcript_segments still round-trips as a parsed structure.
    assert_equal "secret words", recording.reload.transcript_segments.first["text"]

    recording.mark_completed!(
      transcript_text: "the secret passphrase is hunter2",
      document_content: "Top secret meeting notes body",
      work_path: "/tmp/work"
    )
    document = recording.reload.document

    assert_encrypted_at_rest "documents", "content", document.id, "Top secret meeting notes body"
    assert_encrypted_at_rest "documents", "title", document.id, document.title
  end

  private

  # Asserts the raw column value (read straight from the DB, bypassing the model)
  # neither equals nor contains the plaintext, and looks like an AR Encryption
  # envelope. `expected_plaintext` is a substring known to be in the cleartext.
  def assert_encrypted_at_rest(table, column, id, expected_plaintext)
    raw = ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array([ "SELECT #{column} FROM #{table} WHERE id = ?", id ])
    )
    refute_nil raw, "expected a stored value for #{table}.#{column}"
    refute_includes raw, expected_plaintext,
      "#{table}.#{column} still contains plaintext at rest"
    assert_includes raw, "\"p\"",
      "#{table}.#{column} does not look like an Active Record Encryption payload"
  end
end

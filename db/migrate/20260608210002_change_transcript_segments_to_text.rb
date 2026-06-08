class ChangeTranscriptSegmentsToText < ActiveRecord::Migration[8.1]
  # transcript_segments holds diarized transcript content, which we encrypt with
  # Active Record Encryption (see RecordingSession). Encrypted attributes are
  # stored as a base64/JSON string, which a jsonb column rejects, so the column
  # must become text. The model keeps the array/hash interface via
  # `serialize :transcript_segments, coder: JSON`.
  #
  # safety_assured: this is a deliberate, reviewed type change. The cast jsonb→text
  # is lossless (JSON text) and the table is small at this stage; strong_migrations
  # flags any column-type change because it rewrites the table under an ACCESS
  # EXCLUSIVE lock, which is acceptable here.
  def up
    safety_assured do
      change_column :recording_sessions, :transcript_segments, :text
    end
  end

  def down
    safety_assured do
      # Only valid while the column still holds plaintext JSON (i.e. before the
      # encryption backfill); ciphertext cannot be cast back to jsonb.
      execute <<~SQL.squish
        ALTER TABLE recording_sessions
        ALTER COLUMN transcript_segments TYPE jsonb
        USING transcript_segments::jsonb
      SQL
    end
  end
end

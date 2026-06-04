class AddTranscriptSegmentsToRecordingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_sessions, :transcript_segments, :jsonb
  end
end

# Presenter for Wall 1 — the recording-volume wall. Supplies the proof-of-value
# block shown when a trial workspace has used all of its recordings: the
# documents already created and the total time saved across them (summed from
# the same per-recording stat the aha moment uses).
class TrialRecordingWall
  def initialize(workspace)
    @workspace = workspace
  end

  def documents
    @documents ||= workspace.documents.recent_first.to_a
  end

  def documents_count
    documents.size
  end

  def total_time_saved_seconds
    completed_sessions.sum { |session| TrialAhaMoment.new(session).time_saved_seconds }
  end

  def total_time_saved_minutes
    (total_time_saved_seconds / 60.0).round
  end

  private

  attr_reader :workspace

  def completed_sessions
    workspace.recording_sessions.completed
  end
end

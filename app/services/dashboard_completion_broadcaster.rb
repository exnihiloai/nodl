# Pushes the trial-facing dashboard updates that follow a recording finishing
# processing, over the dashboard Turbo stream the user is watching:
#
#   - the "free recordings left" status pill
#   - the aha-moment celebration (when eligible)
#   - the record hero, swapped to Wall 1 once the recording limit is reached so
#     the next reach-forward hits the wall without a page reload
#
# Kept out of the model so RecordingSession#mark_completed! stays a single call.
class DashboardCompletionBroadcaster
  def initialize(recording_session)
    @recording_session = recording_session
    @workspace = recording_session.workspace
  end

  def call
    TrialRecordingsBadge.new(workspace).broadcast!
    TrialAhaMoment.new(recording_session).broadcast!
    broadcast_record_hero if workspace.recording_limit_reached?
  end

  private

  attr_reader :recording_session, :workspace

  def broadcast_record_hero
    Turbo::StreamsChannel.broadcast_replace_to(
      [ workspace, :dashboard ],
      target: "dashboard_record_hero",
      partial: "dashboard/record_hero",
      locals: record_hero_locals
    )
  end

  def record_hero_locals
    TransformerProfile.ensure_default_for!(workspace)
    {
      recording_limit_reached: true,
      recording_session: workspace.recording_sessions.build(transformer_handle: default_transformer_handle),
      transformer_profiles: workspace.transformer_profiles.active.default_first
    }
  end

  def default_transformer_handle
    workspace.transformer_profiles.find_by(default: true)&.handle || TransformerProfile::DEFAULT_HANDLE
  end
end

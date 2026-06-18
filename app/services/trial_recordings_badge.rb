# Presenter for the trial "free recordings left" status pill on the dashboard.
#
# Shown only on the free trial and only once at least one recording has been
# made (so it reads as progress after the first document, never as a wall on a
# fresh account). It reads the recordings entitlement so the limit and the
# append-only used count come straight from the entitlement policy.
class TrialRecordingsBadge
  def initialize(workspace)
    @workspace = workspace
  end

  def visible?
    return false unless workspace&.on_trial?

    used.positive?
  end

  def used
    result.usage.to_i
  end

  def limit
    result.limit.to_i
  end

  def remaining
    [ limit - used, 0 ].max
  end

  # Refresh the pill on the dashboard the user is watching, over the dashboard
  # Turbo stream, after a recording finishes processing.
  def broadcast!
    return unless workspace&.on_trial?

    Turbo::StreamsChannel.broadcast_replace_to(
      [ workspace, :dashboard ],
      target: "trial_recordings_pill",
      partial: "dashboard/trial_recordings_pill",
      locals: { badge: self }
    )
  end

  private

  attr_reader :workspace

  def result
    @result ||= workspace.entitlement_for(:recordings)
  end
end

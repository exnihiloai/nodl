# Decides whether a freshly completed recording should trigger the trial
# "aha moment" celebration, and computes the two numbers it shows:
#
#   X = how long the conversion took (wall-clock processing time)
#   Y = how long the same work would have taken by hand (effort saved)
#
# Effort saved is a piecewise-linear interpolation between the product spec's
# anchor points, expressed as (audio_seconds => effort_seconds):
#
#   1 min  audio  -> ~10 min effort
#   10 min audio  -> ~1 hour effort
#   30 min audio  -> ~2.5 hours effort
#   60 min audio  -> ~5 hours effort
#
# The celebration only fires on the free trial, and only for the workspace's
# first recording or any later recording longer than two minutes.
class TrialAhaMoment
  LONG_RECORDING_SECONDS = 120

  # (audio_seconds, effort_seconds) anchors, ascending. The leading (0, 0)
  # anchor lets short clips interpolate down to zero, and the final segment's
  # slope is extended for anything longer than the last anchor.
  EFFORT_ANCHORS = [
    [ 0, 0 ],
    [ 60, 600 ],
    [ 600, 3600 ],
    [ 1800, 9000 ],
    [ 3600, 18000 ]
  ].freeze

  def initialize(recording_session)
    @recording_session = recording_session
  end

  # Append the celebration to the dashboard the user is watching, over the
  # dashboard Turbo stream. No-op unless this completion qualifies.
  def broadcast!
    return unless eligible?

    Turbo::StreamsChannel.broadcast_append_to(
      [ workspace, :dashboard ],
      target: "aha_moment_slot",
      partial: "dashboard/aha_moment",
      locals: { recording_session: recording_session, aha: self }
    )
  end

  def eligible?
    return false unless recording_session.completed?
    return false unless workspace&.on_trial?

    first_recording? || long_recording?
  end

  # Wall-clock seconds the conversion took, floored at 1 so the copy never reads
  # "0 seconds".
  def conversion_seconds
    started = recording_session.processing_started_at
    finished = recording_session.processing_completed_at
    return 1 unless started && finished

    [ (finished - started).round, 1 ].max
  end

  # Effort saved, in seconds, interpolated from the anchor table.
  def time_saved_seconds
    seconds = audio_seconds
    return 0.0 if seconds <= 0

    (lower, upper) = bracketing_anchors(seconds)
    x0, y0 = lower
    x1, y1 = upper
    y0 + (y1 - y0) * (seconds - x0).to_f / (x1 - x0)
  end

  def time_saved_minutes
    (time_saved_seconds / 60.0).round
  end

  private

  attr_reader :recording_session

  def workspace
    recording_session.workspace
  end

  def first_recording?
    workspace.usage_events.where(event_kind: "recording_created").count <= 1
  end

  def long_recording?
    audio_seconds > LONG_RECORDING_SECONDS
  end

  def audio_seconds
    duration = recording_session.audio_duration
    duration = recording_session.estimated_duration if duration.nil? || duration <= 0
    duration.to_f
  end

  # Returns the [[x0, y0], [x1, y1]] anchor pair surrounding +seconds+. For
  # values past the final anchor, returns the last segment so its slope is
  # extrapolated.
  def bracketing_anchors(seconds)
    EFFORT_ANCHORS.each_cons(2) do |lower, upper|
      return [ lower, upper ] if seconds <= upper[0]
    end

    EFFORT_ANCHORS.last(2)
  end
end

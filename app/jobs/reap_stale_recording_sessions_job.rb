class ReapStaleRecordingSessionsJob < ApplicationJob
  queue_as :default

  # A microphone session is created in :recording status the moment the user
  # hits record, before any audio is uploaded. Normally the browser finalizes
  # it within seconds of stopping. If it never does — tab closed, browser
  # crash, or the recording is abandoned mid-capture — the row would sit in
  # :recording forever, with no audio and nothing of value. The dashboard list
  # and recording quota already ignore :recording rows; this job deletes the
  # stale ones so they don't accumulate.
  #
  # The cutoff is well beyond the maximum recording duration (1 hour) plus
  # finalize time, so a recording that is genuinely still in progress is never
  # reaped.
  STALE_AFTER = 2.hours

  def perform(stale_after: STALE_AFTER)
    RecordingSession
      .recording
      .where(created_at: ..stale_after.ago)
      .find_each(&:destroy!)
  end
end

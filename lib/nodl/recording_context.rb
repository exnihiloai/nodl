module Nodl
  # Human-readable description of when a recording was captured, so the language
  # model can resolve relative references the speaker makes ("today", "right
  # now", "this morning", "by Friday") into the actual date, weekday, and time.
  #
  # The timestamp is rendered in whatever zone it carries (recording_session
  # timestamps come through in the app's configured Time.zone), and the weekday
  # plus zone abbreviation are included so nothing is ambiguous.
  module RecordingContext
    # Phrased as a passive reference fact, not a command: the model should know
    # "now" so it can resolve the speaker's relative references, but must NOT
    # volunteer the date or time unless the speech or the instructions call for
    # it. The earlier "reference it explicitly" wording made every document open
    # with a timestamp even when irrelevant.
    INSTRUCTION =
      "For reference, this recording was created on %s. Use this only to " \
      "resolve relative references the speaker makes (such as \"today\", " \
      "\"right now\", or a day of the week) or when the instructions ask for " \
      "the date or time. Do not otherwise mention the date or time in the " \
      "document.".freeze

    module_function

    # Returns nil when no timestamp is known, so callers can omit the section
    # entirely rather than emit an empty or fabricated one.
    def describe(recorded_at)
      return if recorded_at.nil?

      format(INSTRUCTION, format_moment(recorded_at))
    end

    def format_moment(recorded_at)
      recorded_at.strftime("%A, %-d %B %Y at %H:%M %Z")
    end
  end
end

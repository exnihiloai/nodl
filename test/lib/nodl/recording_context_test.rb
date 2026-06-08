require "test_helper"
require "nodl/recording_context"

class NodlRecordingContextTest < ActiveSupport::TestCase
  test "describes the recording moment with weekday, date, time, and zone" do
    moment = Time.utc(2026, 6, 8, 14, 30) # a Monday

    description = Nodl::RecordingContext.describe(moment)

    assert_includes description, "Monday, 8 June 2026 at 14:30 UTC"
  end

  test "instructs the model not to volunteer the date or time when irrelevant" do
    description = Nodl::RecordingContext.describe(Time.utc(2026, 6, 8, 14, 30))

    assert_includes description, "Do not otherwise mention the date or time"
    assert_includes description, "resolve relative references"
  end

  test "returns nil when no timestamp is known" do
    assert_nil Nodl::RecordingContext.describe(nil)
  end

  test "renders the timestamp in whatever zone it carries" do
    Time.use_zone("Europe/Berlin") do
      moment = Time.zone.local(2026, 6, 8, 16, 30) # CEST

      assert_includes Nodl::RecordingContext.describe(moment), "16:30 CEST"
    end
  end
end

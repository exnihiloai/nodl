require "test_helper"

class RecordingSessionsLiveTranscriptSegmentsTest < ActionView::TestCase
  test "live transcript segment replacement keeps the turbo target id" do
    render partial: "recording_sessions/live_transcript_segments", locals: { segments: [ "First sentence.", "Second sentence." ] }

    assert_select "#live_transcript_segments", count: 1
    assert_select "#live_transcript_segments", text: /First sentence/
    assert_select "#live_transcript_segments", text: /Second sentence/
  end

  test "empty live transcript segment replacement keeps the turbo target id" do
    render partial: "recording_sessions/live_transcript_segments", locals: { segments: [] }

    assert_select "#live_transcript_segments", count: 1
    assert_select "#live_transcript_segments", text: /Your live transcript will appear here/
  end
end

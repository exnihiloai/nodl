require "test_helper"

class RecordingSessionsHelperTest < ActionView::TestCase
  def segment(speaker, start: 0.0, finish: 1.0)
    { "start" => start, "end" => finish, "speaker" => speaker, "text" => "#{speaker}: hi", "words" => [] }
  end

  test "detects multi vs single speaker" do
    assert multi_speaker_transcript?([ segment("speaker_1"), segment("speaker_2") ])
    assert_not multi_speaker_transcript?([ segment("speaker_1"), segment("speaker_1") ])
    assert_not multi_speaker_transcript?([])
  end

  test "assigns a distinct color per speaker in appearance order" do
    map = speaker_color_map([ segment("speaker_1"), segment("speaker_2"), segment("speaker_1") ])

    assert_equal %w[speaker_1 speaker_2], map.keys
    assert_not_equal map["speaker_1"], map["speaker_2"]
  end

  test "strips a leading speaker label from text" do
    assert_equal "hello there", strip_speaker_label("speaker_1: hello there")
    assert_equal "hello there", strip_speaker_label("Speaker 2 : hello there")
    assert_equal "no label", strip_speaker_label("no label")
  end

  test "groups consecutive segments into speaker turns with stable appearance-order numbers" do
    turns = transcript_speaker_turns([
      { "speaker" => "speaker_2", "text" => "Speaker 2: First." },
      { "speaker" => "speaker_2", "text" => "Still first." },
      { "speaker" => nil, "text" => "Unidentified." },
      { "speaker" => "speaker_7", "text" => "Speaker 7: Second." },
      { "speaker" => "speaker_2", "text" => "Speaker 2: First again." }
    ])

    assert_equal [
      { speaker: "speaker_2", number: 1, text: "First. Still first." },
      { speaker: nil, number: nil, text: "Unidentified." },
      { speaker: "speaker_7", number: 2, text: "Second." },
      { speaker: "speaker_2", number: 1, text: "First again." }
    ], turns
  end

  test "drops blank segment runs from speaker turns" do
    turns = transcript_speaker_turns([
      { "speaker" => "speaker_1", "text" => "Speaker 1:" },
      { "speaker" => "speaker_2", "text" => "Speaker 2: Hello." }
    ])

    assert_equal [ { speaker: "speaker_2", number: 2, text: "Hello." } ], turns
  end

  test "formats annotated plain text with bracketed localized labels and paragraph breaks" do
    text = annotated_transcript_plain_text([
      { "speaker" => "speaker_1", "text" => "Speaker 1: Hello." },
      { "speaker" => "speaker_2", "text" => "Speaker 2: Hi." },
      { "speaker" => "speaker_1", "text" => "Speaker 1: Welcome back." }
    ])

    assert_equal "[Person 1] Hello.\n\n[Person 2] Hi.\n\n[Person 1] Welcome back.", text
  end

  test "escapes transcript content in annotated html" do
    html = annotated_transcript_html([
      { "speaker" => "speaker_1", "text" => "Speaker 1: <script>alert('x')</script>" },
      { "speaker" => "speaker_2", "text" => "Speaker 2: Safe." }
    ])

    assert_includes html, "<strong>[Person 1]</strong>"
    assert_includes html, "&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;"
    refute_includes html, "<script>"
  end

  test "does not annotate a single-speaker transcript" do
    segments = [
      { "speaker" => "speaker_1", "text" => "Speaker 1: Hello." },
      { "speaker" => "speaker_1", "text" => "Still me." }
    ]

    assert_nil annotated_transcript_plain_text(segments)
    assert_nil annotated_transcript_html(segments)
  end

  test "transcript_timeline keeps start/end/speaker and drops incomplete segments" do
    timeline = transcript_timeline([
      { "start" => 0.0, "end" => 1.0, "speaker" => "speaker_1" },
      { "start" => nil, "end" => 2.0, "speaker" => "speaker_2" }
    ])

    assert_equal 1, timeline.size
    assert_equal({ "start" => 0.0, "end" => 1.0, "speaker" => "speaker_1" }, timeline.first)
  end
end

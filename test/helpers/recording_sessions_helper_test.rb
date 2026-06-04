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

  test "transcript_timeline keeps start/end/speaker and drops incomplete segments" do
    timeline = transcript_timeline([
      { "start" => 0.0, "end" => 1.0, "speaker" => "speaker_1" },
      { "start" => nil, "end" => 2.0, "speaker" => "speaker_2" }
    ])

    assert_equal 1, timeline.size
    assert_equal({ "start" => 0.0, "end" => 1.0, "speaker" => "speaker_1" }, timeline.first)
  end
end

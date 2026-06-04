require "test_helper"
require "nodl/audio_input"
require "nodl/transcription/voxtral_transcriber"

class NodlVoxtralTranscriberTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :path, :model, :diarize, :timestamp_granularities

    def transcribe(path:, model:, diarize:, timestamp_granularities:, **)
      @path = path
      @model = model
      @diarize = diarize
      @timestamp_granularities = timestamp_granularities
      {
        "text" => "Welcome. Thanks.",
        "language" => "en",
        "usage" => { "prompt_audio_seconds" => 12.5 },
        "segments" => [
          {
            "start" => 0.0,
            "end" => 1.2,
            "speaker" => "Speaker 1",
            "text" => "Welcome.",
            "words" => [ { "start" => 0.0, "end" => 0.8, "word" => "Welcome" } ]
          },
          {
            "start" => 1.3,
            "end" => 2.0,
            "speaker" => "Speaker 2",
            "text" => "Thanks.",
            "words" => [ { "start" => 1.3, "end" => 1.9, "word" => "Thanks" } ]
          }
        ]
      }
    end
  end

  test "transcribes with diarization and normalizes structured timestamps" do
    client = FakeClient.new
    audio = Nodl::AudioInput.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"))

    result = Nodl::Transcription::VoxtralTranscriber.new(client: client).transcribe(audio: audio, model: "voxtral-mini-latest")

    assert_equal true, client.diarize
    assert_equal %w[segment], client.timestamp_granularities
    assert_equal "Speaker 1: Welcome.\nSpeaker 2: Thanks.", result.text
    assert_equal "en", result.language
    assert_equal 12.5, result.audio_seconds
    assert_equal "Speaker 1", result.segments.first.fetch("speaker")
    assert_equal "Welcome", result.segments.first.fetch("words").first.fetch("word")
    assert_equal 0.0, result.segments.first.fetch("words").first.fetch("start")
  end
end

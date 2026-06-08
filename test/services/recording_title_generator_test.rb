require "test_helper"

class RecordingTitleGeneratorTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :model, :parts, :generation_config

    def initialize(response)
      @response = response
    end

    def generate_text(model:, parts:, generation_config:)
      @model = model
      @parts = parts
      @generation_config = generation_config
      @response
    end
  end

  test "generates a title from transcript text" do
    client = FakeClient.new("Project Planning Notes")
    title = RecordingTitleGenerator.new(client: client).generate(transcript: "We discussed the product roadmap.")

    assert_equal "Project Planning Notes", title
    assert_equal RecordingTitleGenerator::DEFAULT_MODEL, client.model
    assert_includes client.parts.first.fetch(:text), "We discussed the product roadmap."
    assert_equal({ temperature: 0.2 }, client.generation_config)
  end

  test "includes the recording date and time in the prompt when recorded_at is given" do
    client = FakeClient.new("Daily Standup")
    RecordingTitleGenerator.new(client: client).generate(
      transcript: "Today and right now I am speaking these words.",
      recorded_at: Time.utc(2026, 6, 8, 14, 30)
    )

    assert_includes client.parts.first.fetch(:text), "Monday, 8 June 2026 at 14:30 UTC"
  end

  test "omits recording context from the prompt when recorded_at is nil" do
    client = FakeClient.new("Daily Standup")
    RecordingTitleGenerator.new(client: client).generate(transcript: "We discussed the roadmap.")

    refute_includes client.parts.first.fetch(:text), "Recording context"
  end

  test "returns nil without calling the model when the transcript is blank" do
    [ "", "   ", "\n\t", nil ].each do |blank|
      client = FakeClient.new("Please provide the transcript you would like me to title")

      title = RecordingTitleGenerator.new(client: client).generate(transcript: blank)

      assert_nil title, "expected no title for blank transcript #{blank.inspect}"
      assert_nil client.model, "model should not be called for blank transcript #{blank.inspect}"
    end
  end

  test "sanitizes markdown, quotes, trailing punctuation, and long responses" do
    client = FakeClient.new("# \"This Is A Very Long Title That Should Be Trimmed Because It Has Far Too Many Words.\"")
    title = RecordingTitleGenerator.new(client: client).generate(transcript: "Transcript")

    assert_equal "This Is A Very Long Title That Should Be Trimmed Because It Has Far Too Many Wor", title
    assert_operator title.length, :<=, RecordingTitleGenerator::MAX_TITLE_LENGTH
  end
end

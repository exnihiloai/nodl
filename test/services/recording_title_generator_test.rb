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

  test "sanitizes markdown, quotes, trailing punctuation, and long responses" do
    client = FakeClient.new("# \"This Is A Very Long Title That Should Be Trimmed Because It Has Far Too Many Words.\"")
    title = RecordingTitleGenerator.new(client: client).generate(transcript: "Transcript")

    assert_equal "This Is A Very Long Title That Should Be Trimmed Because It Has Far Too Many Wor", title
    assert_operator title.length, :<=, RecordingTitleGenerator::MAX_TITLE_LENGTH
  end
end

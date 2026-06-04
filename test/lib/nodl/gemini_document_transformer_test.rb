require "test_helper"
require "nodl/transformation/gemini_document_transformer"

class NodlGeminiDocumentTransformerTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:captured, keyword_init: true) do
    def generate_text(model:, parts:, generation_config:)
      self.captured = { model: model, parts: parts, generation_config: generation_config }
      "# Generated Document"
    end
  end

  test "builds a prompt from defaults, transformer instructions, templates, and transcript" do
    transformer = Nodl::Transformation::Transformer.new(
      handle: "meeting-notes",
      instructions: "Use concise meeting notes.",
      templates: [
        Nodl::Transformation::Template.new(name: "example.md", content: "# Example")
      ]
    )

    prompt = Nodl::Transformation::GeminiDocumentTransformer.new.build_prompt(
      transcript: "Raw transcript text.",
      transformer: transformer
    )

    assert_includes prompt, "Default instructions"
    assert_includes prompt, "meeting-notes"
    assert_includes prompt, "Use concise meeting notes."
    assert_includes prompt, "### example.md"
    assert_includes prompt, "# Example"
    assert_includes prompt, "Raw transcript text."
  end

  test "sends prompt to gemini with expected model and generation config" do
    client = FakeClient.new
    transformer = Nodl::Transformation::Transformer.new(handle: "default", instructions: "Clean it.", templates: [])

    document = Nodl::Transformation::GeminiDocumentTransformer.new(client: client).transform(
      transcript: "Transcript",
      transformer: transformer,
      model: "gemini-3.1-flash-lite"
    )

    assert_equal "# Generated Document", document
    assert_equal "gemini-3.1-flash-lite", client.captured.fetch(:model)
    assert_equal({ temperature: 0.2 }, client.captured.fetch(:generation_config))
    assert_includes client.captured.fetch(:parts).first.fetch(:text), "Transcript"
  end
end

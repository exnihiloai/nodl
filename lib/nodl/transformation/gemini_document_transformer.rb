require_relative "../providers/gemini_client"

module Nodl
  module Transformation
    class GeminiDocumentTransformer
      DEFAULT_INSTRUCTIONS = <<~INSTRUCTIONS.freeze
        You transform raw speech transcripts into clean, useful Markdown documents.
        Improve punctuation, grammar, headings, paragraph structure, bullet points, and readability.
        Preserve the meaning of the original transcript and do not invent facts.
        Return only Markdown.
      INSTRUCTIONS

      def initialize(client: nil)
        @client = client
      end

      def transform(transcript:, transformer:, model:)
        client.generate_text(
          model: model,
          parts: [ { text: build_prompt(transcript: transcript, transformer: transformer) } ],
          generation_config: { temperature: 0.2 }
        )
      end

      def build_prompt(transcript:, transformer:)
        sections = [
          [ "Default instructions", DEFAULT_INSTRUCTIONS ],
          [ "Transformer handle", transformer.handle ],
          [ "Transformer instructions", transformer.instructions ],
          [ "Templates", templates_content(transformer.templates) ],
          [ "Raw transcript", transcript ]
        ]

        sections.map { |title, content| "## #{title}\n\n#{content}" }.join("\n\n")
      end

      private

      def client
        @client ||= Providers::GeminiClient.new
      end

      def templates_content(templates)
        return "No templates provided." if templates.empty?

        templates.map do |template|
          "### #{template.name}\n\n#{template.content}"
        end.join("\n\n")
      end
    end
  end
end

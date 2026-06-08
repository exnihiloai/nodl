require_relative "../providers/gemini_client"
require_relative "../recording_context"
require_relative "transformer_repository"

module Nodl
  module Transformation
    class GeminiDocumentTransformer
      DEFAULT_INSTRUCTIONS = <<~INSTRUCTIONS.freeze
        You transform raw speech transcripts into clean, useful Markdown documents.
        Improve punctuation, grammar, headings, paragraph structure, bullet points, and readability.
        Preserve the meaning of the original transcript and do not invent facts.
        Return only Markdown. Use the language of the transcript for all text in the markdown document.
      INSTRUCTIONS

      # Returned for recordings with no speech. Asking the model to write a
      # document from an empty transcript yields chatty filler ("This is an
      # empty recording..."), so we skip the call and return a clear,
      # deterministic placeholder instead.
      EMPTY_TRANSCRIPT_DOCUMENT = <<~MARKDOWN.freeze
        # No speech detected
      MARKDOWN

      def initialize(client: nil)
        @client = client
      end

      def transform(transcript:, transformer:, model:, recorded_at: nil)
        return EMPTY_TRANSCRIPT_DOCUMENT if transcript.to_s.strip.blank?

        client.generate_text(
          model: model,
          parts: [ { text: build_prompt(transcript: transcript, transformer: transformer, recorded_at: recorded_at) } ],
          generation_config: { temperature: 0.2 }
        )
      end

      def build_prompt(transcript:, transformer:, recorded_at: nil)
        sections = [
          [ "Default instructions", DEFAULT_INSTRUCTIONS ],
          [ "Recording context", RecordingContext.describe(recorded_at) ],
          [ "Transformer handle", transformer.handle ],
          [ "Transformer instructions", transformer.instructions ],
          [ "Templates", templates_content(transformer.templates) ],
          [ "Raw transcript", transcript ]
        ]

        sections
          .reject { |_title, content| content.to_s.strip.empty? }
          .map { |title, content| "## #{title}\n\n#{content}" }
          .join("\n\n")
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

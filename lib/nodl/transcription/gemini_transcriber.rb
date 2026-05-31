require_relative "../providers/gemini_client"

module Nodl
  module Transcription
    Result = Struct.new(:text, :file_uri, keyword_init: true)

    class GeminiTranscriber
      PROMPT = <<~PROMPT.freeze
        Generate a faithful transcript of this audio file.

        Requirements:
        - Preserve the speaker's language.
        - If there are multiple speakers, add speaker tags that identify each distinct speaker as clearly as possible.
        - Add punctuation and paragraphs where helpful.
        - Do not summarize.
        - Return only the transcript text.
      PROMPT

      def initialize(client: Providers::GeminiClient.new)
        @client = client
      end

      def transcribe(audio:, model:)
        upload = client.upload_file(path: audio.path, mime_type: audio.mime_type, display_name: audio.basename)
        file_uri = upload.dig("file", "uri")
        raise GeminiError, "Gemini file upload response did not include file.uri." if file_uri.blank?

        text = client.generate_text(
          model: model,
          parts: [
            { text: PROMPT },
            { file_data: { mime_type: audio.mime_type, file_uri: file_uri } }
          ],
          generation_config: { temperature: 0.0 }
        )

        Result.new(text: text, file_uri: file_uri)
      end

      private

      attr_reader :client
    end
  end
end

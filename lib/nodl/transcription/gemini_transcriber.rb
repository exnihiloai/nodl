require_relative "../providers/gemini_client"

module Nodl
  module Transcription
    Result = Struct.new(:text, :file_uri, keyword_init: true)

    class GeminiTranscriber
      PROMPT = <<~PROMPT.freeze
        Generate a faithful transcript of this audio file.

        Requirements:
        - Preserve the speaker's language.
        - If there is only one speaker, do not add speaker labels.
        - If there are multiple speakers, label each turn with stable ordinal labels: Speaker 1:, Speaker 2:, Speaker 3:, and so on.
        - Keep each speaker number consistent across the whole transcript. Do not guess names.
        - Add punctuation and paragraphs where helpful.
        - Do not summarize.
        - Return only the transcript text.
      PROMPT

      PREVIEW_PROMPT = <<~PROMPT.freeze
        Generate a short, faithful transcript of this audio segment.

        Requirements:
        - Preserve the speaker's language.
        - Do not add speaker labels.
        - Add punctuation where helpful.
        - Do not summarize.
        - Return only the transcript text.
      PROMPT

      def initialize(client: Providers::GeminiClient.new)
        @client = client
      end

      def transcribe(audio:, model:, preview: false)
        upload = client.upload_file(path: audio.path, mime_type: audio.mime_type, display_name: audio.basename)
        file_uri = upload.dig("file", "uri")
        raise GeminiError, "Gemini file upload response did not include file.uri." if file_uri.blank?

        text = client.generate_text(
          model: model,
          parts: [
            { text: preview ? PREVIEW_PROMPT : PROMPT },
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

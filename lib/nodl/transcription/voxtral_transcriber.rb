require_relative "../providers/mistral_client"

module Nodl
  module Transcription
    Result = Struct.new(:text, :file_uri, :segments, :language, :audio_seconds, keyword_init: true)

    class VoxtralTranscriber
      DEFAULT_TIMESTAMP_GRANULARITIES = %w[segment].freeze

      def initialize(client: Providers::MistralClient.new)
        @client = client
      end

      def transcribe(audio:, model:, language: nil)
        payload = client.transcribe(
          path: audio.path,
          model: model,
          diarize: true,
          timestamp_granularities: DEFAULT_TIMESTAMP_GRANULARITIES,
          language: language
        )

        segments = normalize_segments(payload.fetch("segments", []))
        Result.new(
          text: transcript_text(payload.fetch("text", ""), segments),
          segments: segments,
          language: payload["language"],
          audio_seconds: payload.dig("usage", "prompt_audio_seconds")
        )
      end

      private

      attr_reader :client

      def normalize_segments(raw_segments)
        raw_segments.map do |segment|
          {
            "start" => segment["start"],
            "end" => segment["end"],
            "speaker" => segment["speaker"].presence || segment["speaker_id"].presence,
            "text" => segment["text"].to_s,
            "words" => normalize_words(segment["words"])
          }.compact
        end
      end

      def normalize_words(raw_words)
        Array(raw_words).map do |word|
          {
            "start" => word["start"],
            "end" => word["end"],
            "word" => word["word"].presence || word["text"].to_s
          }.compact
        end
      end

      def transcript_text(raw_text, segments)
        return raw_text.to_s.strip if segments.blank? || segments.none? { |segment| segment["speaker"].present? }

        segments.filter_map do |segment|
          text = segment["text"].to_s.strip
          next if text.blank?

          speaker = segment["speaker"].presence || "Speaker"
          "#{speaker}: #{text}"
        end.join("\n").strip.presence || raw_text.to_s.strip
      end
    end
  end
end

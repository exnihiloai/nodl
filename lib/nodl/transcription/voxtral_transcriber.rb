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

      # Leading "speaker_1:" / "Speaker 1:" label that Voxtral prepends to each
      # diarized segment (and to each line of the top-level text).
      SPEAKER_PREFIX = /\Aspeaker[\s_-]*\d+\s*:\s*/i

      # The displayed/document transcript is clean flowing prose: no speaker
      # labels and no per-segment line breaks (those read as choppy and
      # confusing for single-speaker dictation). With diarization on, Voxtral
      # puts "speaker_N:" labels into both the segment text and the top-level
      # text, so we strip them and join with spaces. Speaker attribution and
      # timestamps are preserved in the structured `segments` for later use.
      def transcript_text(raw_text, segments)
        from_segments = segments.filter_map { |segment| strip_speaker_label(segment["text"]) }.join(" ")
        return from_segments if from_segments.present?

        raw_text.to_s.split("\n").filter_map { |line| strip_speaker_label(line) }.join(" ")
      end

      def strip_speaker_label(text)
        text.to_s.strip.sub(SPEAKER_PREFIX, "").strip.presence
      end
    end
  end
end

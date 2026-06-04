require "fileutils"
require "json"
require "time"
require_relative "audio_input"
require_relative "audio/waveform_extractor"
require_relative "providers/gemini_client"
require_relative "transcription/voxtral_transcriber"
require_relative "transformation/gemini_document_transformer"
require_relative "transformation/transformer_repository"
require_relative "working_directory"

module Nodl
  class Pipeline
    Result = Struct.new(:session_path, :audio_path, :transcript_path, :transcript_segments_path, :document_path, :metadata_path, :transcript_segments, :waveform_peaks, :audio_duration, keyword_init: true)

    def initialize(
      transcriber: nil,
      document_transformer: nil,
      transformer_repository: Transformation::TransformerRepository.new,
      working_directory: WorkingDirectory.new,
      waveform_extractor: Audio::WaveformExtractor.new
    )
      gemini_client = Providers::GeminiClient.new if document_transformer.nil?
      @transcriber = transcriber || Transcription::VoxtralTranscriber.new
      @document_transformer = document_transformer || Transformation::GeminiDocumentTransformer.new(client: gemini_client)
      @transformer_repository = transformer_repository
      @working_directory = working_directory
      @waveform_extractor = waveform_extractor
    end

    def run(audio_path:, transformer_handle:, transcriber_model:, transformer_model:)
      started_at = Time.now.utc
      source_audio = AudioInput.new(audio_path)
      transformer = transformer_repository.fetch(transformer_handle)
      session = working_directory.create_session(source_audio, now: started_at)
      FileUtils.cp(source_audio.path, session.audio_path)

      session_audio = AudioInput.new(session.audio_path)
      waveform = extract_waveform(session.audio_path)
      transcript = transcriber.transcribe(audio: session_audio, model: transcriber_model)
      session.transcript_path.write("#{transcript.text.strip}\n")
      session.transcript_segments_path.write("#{JSON.pretty_generate(transcript.segments || [])}\n")

      document = document_transformer.transform(
        transcript: transcript.text,
        transformer: transformer,
        model: transformer_model
      )
      session.document_path.write("#{document.strip}\n")
      write_metadata(
        session: session,
        source_audio: source_audio,
        transformer: transformer,
        transcriber_model: transcriber_model,
        transformer_model: transformer_model,
        transcript_language: transcript.language,
        transcript_audio_seconds: transcript.audio_seconds,
        started_at: started_at,
        completed_at: Time.now.utc
      )

      Result.new(
        session_path: session.path,
        audio_path: session.audio_path,
        transcript_path: session.transcript_path,
        transcript_segments_path: session.transcript_segments_path,
        document_path: session.document_path,
        metadata_path: session.metadata_path,
        transcript_segments: transcript.segments || [],
        waveform_peaks: waveform.peaks,
        audio_duration: waveform.duration
      )
    end

    private

    attr_reader :transcriber, :document_transformer, :transformer_repository, :working_directory, :waveform_extractor

    # The waveform is a nicety, not core output — never fail the whole recording
    # because the envelope could not be computed.
    def extract_waveform(audio_path)
      waveform_extractor.extract(audio_path)
    rescue StandardError => error
      warn "Waveform extraction failed: #{error.message}"
      Audio::WaveformExtractor::Result.new(peaks: [], duration: 0.0)
    end

    def write_metadata(session:, source_audio:, transformer:, transcriber_model:, transformer_model:, transcript_language:, transcript_audio_seconds:, started_at:, completed_at:)
      metadata = {
        source_audio_path: source_audio.path.to_s,
        copied_audio_path: session.audio_path.to_s,
        transcript_path: session.transcript_path.to_s,
        transcript_segments_path: session.transcript_segments_path.to_s,
        document_path: session.document_path.to_s,
        transformer_handle: transformer.handle,
        transcriber_model: transcriber_model,
        transformer_model: transformer_model,
        transcript_language: transcript_language,
        transcript_audio_seconds: transcript_audio_seconds,
        started_at: started_at.iso8601,
        completed_at: completed_at.iso8601
      }

      session.metadata_path.write("#{JSON.pretty_generate(metadata)}\n")
    end
  end
end

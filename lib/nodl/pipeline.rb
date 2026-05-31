require "fileutils"
require "json"
require "time"
require_relative "audio_input"
require_relative "transcription/gemini_transcriber"
require_relative "transformation/gemini_document_transformer"
require_relative "transformation/transformer_repository"
require_relative "working_directory"

module Nodl
  class Pipeline
    Result = Struct.new(:session_path, :audio_path, :transcript_path, :document_path, :metadata_path, keyword_init: true)

    def initialize(
      transcriber: nil,
      document_transformer: nil,
      transformer_repository: Transformation::TransformerRepository.new,
      working_directory: WorkingDirectory.new
    )
      client = Providers::GeminiClient.new if transcriber.nil? || document_transformer.nil?
      @transcriber = transcriber || Transcription::GeminiTranscriber.new(client: client)
      @document_transformer = document_transformer || Transformation::GeminiDocumentTransformer.new(client: client)
      @transformer_repository = transformer_repository
      @working_directory = working_directory
    end

    def run(audio_path:, transformer_handle:, transcriber_model:, transformer_model:)
      started_at = Time.now.utc
      source_audio = AudioInput.new(audio_path)
      transformer = transformer_repository.fetch(transformer_handle)
      session = working_directory.create_session(source_audio, now: started_at)
      FileUtils.cp(source_audio.path, session.audio_path)

      session_audio = AudioInput.new(session.audio_path)
      transcript = transcriber.transcribe(audio: session_audio, model: transcriber_model)
      session.transcript_path.write("#{transcript.text.strip}\n")

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
        gemini_file_uri: transcript.file_uri,
        started_at: started_at,
        completed_at: Time.now.utc
      )

      Result.new(
        session_path: session.path,
        audio_path: session.audio_path,
        transcript_path: session.transcript_path,
        document_path: session.document_path,
        metadata_path: session.metadata_path
      )
    end

    private

    attr_reader :transcriber, :document_transformer, :transformer_repository, :working_directory

    def write_metadata(session:, source_audio:, transformer:, transcriber_model:, transformer_model:, gemini_file_uri:, started_at:, completed_at:)
      metadata = {
        source_audio_path: source_audio.path.to_s,
        copied_audio_path: session.audio_path.to_s,
        transcript_path: session.transcript_path.to_s,
        document_path: session.document_path.to_s,
        transformer_handle: transformer.handle,
        transcriber_model: transcriber_model,
        transformer_model: transformer_model,
        gemini_file_uri: gemini_file_uri,
        started_at: started_at.iso8601,
        completed_at: completed_at.iso8601
      }

      session.metadata_path.write("#{JSON.pretty_generate(metadata)}\n")
    end
  end
end

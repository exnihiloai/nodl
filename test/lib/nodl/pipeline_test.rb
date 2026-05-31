require "test_helper"
require "tmpdir"

class NodlPipelineTest < ActiveSupport::TestCase
  FakeTranscription = Struct.new(:text, :file_uri, keyword_init: true)

  class FakeTranscriber
    attr_reader :audio, :model

    def transcribe(audio:, model:)
      @audio = audio
      @model = model
      FakeTranscription.new(text: "This is the transcript.", file_uri: "files/test-audio")
    end
  end

  class FakeDocumentTransformer
    attr_reader :transcript, :transformer, :model

    def transform(transcript:, transformer:, model:)
      @transcript = transcript
      @transformer = transformer
      @model = model
      "# Document\n\nGenerated from transcript."
    end
  end

  test "runs the pipeline and writes all working files" do
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      transformer_root = root.join("transformers")
      transformer_root.join("default", "templates").mkpath
      transformer_root.join("default", "instructions.md").write("Create a document.")
      work_root = root.join("work")
      transcriber = FakeTranscriber.new
      document_transformer = FakeDocumentTransformer.new

      result = Nodl::Pipeline.new(
        transcriber: transcriber,
        document_transformer: document_transformer,
        transformer_repository: Nodl::Transformation::TransformerRepository.new(root_path: transformer_root),
        working_directory: Nodl::WorkingDirectory.new(root_path: work_root)
      ).run(
        audio_path: Rails.root.join("test", "fixtures", "files", "sample.mp3"),
        transformer_handle: "default",
        transcriber_model: "transcriber-model",
        transformer_model: "transformer-model"
      )

      assert_predicate result.audio_path, :file?
      assert_equal "This is the transcript.\n", result.transcript_path.read
      assert_equal "# Document\n\nGenerated from transcript.\n", result.document_path.read
      metadata = JSON.parse(result.metadata_path.read)
      assert_equal "default", metadata.fetch("transformer_handle")
      assert_equal "transcriber-model", metadata.fetch("transcriber_model")
      assert_equal "transformer-model", metadata.fetch("transformer_model")
      assert_equal "files/test-audio", metadata.fetch("gemini_file_uri")
      assert_equal result.audio_path.to_s, transcriber.audio.path.to_s
      assert_equal "This is the transcript.", document_transformer.transcript
    end
  end
end

require "test_helper"

class RecordingSessionProcessorTest < ActiveSupport::TestCase
  NormalizedAudio = Struct.new(:path, :converted, :content_type, :filename, keyword_init: true) do
    def converted?
      converted
    end
  end

  PipelineResult = Struct.new(:session_path, :transcript_path, :document_path, keyword_init: true)

  class FakeNormalizer
    attr_reader :input_path

    def initialize(converted: false)
      @converted = converted
    end

    def normalize(input_path:, **)
      @input_path = input_path
      NormalizedAudio.new(path: input_path, converted: @converted, content_type: "audio/mpeg", filename: "normalized.mp3")
    end
  end

  class FakePipeline
    attr_reader :audio_path, :transformer_handle

    def initialize(transcript_text: "Generated transcript")
      @transcript_text = transcript_text
    end

    def run(audio_path:, transformer_handle:, **)
      @audio_path = audio_path
      @transformer_handle = transformer_handle
      transcript = Tempfile.new("transcript")
      transcript.write(@transcript_text)
      transcript.flush
      document = Tempfile.new("document")
      document.write("# Generated document")
      document.flush
      PipelineResult.new(session_path: Pathname.new("/tmp/work/session"), transcript_path: Pathname.new(transcript.path), document_path: Pathname.new(document.path))
    end
  end

  test "processes a recording session and stores transcript and document" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Demo session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    normalizer = FakeNormalizer.new
    pipeline = FakePipeline.new

    RecordingSessionProcessor.new(normalizer: normalizer, pipeline: pipeline).call(recording_session)

    assert_predicate recording_session.reload, :completed?
    assert_equal "Generated transcript", recording_session.transcript_text
    assert_equal "# Generated document", recording_session.document.content
    assert_equal "default", pipeline.transformer_handle
  end

  test "persists speaker-attributed transcript from the authoritative pipeline" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Interview",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    pipeline = FakePipeline.new(transcript_text: "Speaker 1: Welcome.\nSpeaker 2: Thanks for having me.")

    RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: pipeline).call(recording_session)

    assert_predicate recording_session.reload, :completed?
    assert_equal "Speaker 1: Welcome.\nSpeaker 2: Thanks for having me.", recording_session.transcript_text
    assert_equal "# Generated document", recording_session.document.content
  end

  test "persists single-speaker transcript without adding labels" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Solo note",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    pipeline = FakePipeline.new(transcript_text: "This is a single-speaker note.")

    RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: pipeline).call(recording_session)

    assert_predicate recording_session.reload, :completed?
    assert_equal "This is a single-speaker note.", recording_session.transcript_text
    assert_no_match(/Speaker \d+:/, recording_session.transcript_text)
  end

  test "marks the session failed when processing raises" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Broken",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    pipeline = stub
    pipeline.stubs(:run).raises(Nodl::Error, "pipeline failed")

    assert_raises(Nodl::Error) do
      RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: pipeline).call(recording_session)
    end

    assert_predicate recording_session.reload, :failed?
    assert_equal "pipeline failed", recording_session.error_message
  end
end

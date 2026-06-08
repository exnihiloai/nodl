require "test_helper"

class RecordingSessionProcessorTest < ActiveSupport::TestCase
  NormalizedAudio = Struct.new(:path, :converted, :content_type, :filename, keyword_init: true) do
    def converted?
      converted
    end
  end

  PipelineResult = Struct.new(:session_path, :transcript_path, :document_path, :transcript_segments, :waveform_peaks, :audio_duration, keyword_init: true)

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
      @transcript_segments = [
        {
          "start" => 0.0,
          "end" => 1.0,
          "speaker" => "Speaker 1",
          "text" => transcript_text,
          "words" => []
        }
      ]
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
      PipelineResult.new(session_path: Pathname.new("/tmp/work/session"), transcript_path: Pathname.new(transcript.path), document_path: Pathname.new(document.path), transcript_segments: @transcript_segments, waveform_peaks: [ 0.2, 0.8, 1.0 ], audio_duration: 7.5)
    end
  end

  class FakeTitleGenerator
    attr_reader :transcript, :recorded_at

    def initialize(title: "Generated Meeting Title", error: nil)
      @title = title
      @error = error
    end

    def generate(transcript:, recorded_at: nil)
      raise @error if @error

      @transcript = transcript
      @recorded_at = recorded_at
      @title
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
    assert_equal "Speaker 1", recording_session.transcript_segments.first.fetch("speaker")
    assert_equal "# Generated document", recording_session.document.content
    assert_equal "default", pipeline.transformer_handle
    assert_equal [ 0.2, 0.8, 1.0 ], recording_session.waveform_peaks
    assert_equal 7.5, recording_session.audio_duration
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

  test "generates a meaningful title when session still has the default title" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    title_generator = FakeTitleGenerator.new(title: "Sebastians Aufnahme Test")
    pipeline = FakePipeline.new(transcript_text: "Hallo, ich mache hier eine Aufnahme.")

    RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: pipeline, title_generator: title_generator).call(recording_session)

    assert_predicate recording_session.reload, :completed?
    assert_equal "Sebastians Aufnahme Test", recording_session.title
    assert_equal "Sebastians Aufnahme Test", recording_session.document.title
    assert_equal "Hallo, ich mache hier eine Aufnahme.", title_generator.transcript
  end

  test "keeps an explicit user title instead of generating one" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Client interview",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    title_generator = FakeTitleGenerator.new(title: "Generated title")

    RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: FakePipeline.new, title_generator: title_generator).call(recording_session)

    assert_predicate recording_session.reload, :completed?
    assert_equal "Client interview", recording_session.title
    assert_equal "Client interview", recording_session.document.title
    assert_nil title_generator.transcript
  end

  test "keeps default title when title generation fails" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    title_generator = FakeTitleGenerator.new(error: Nodl::GeminiError.new("temporary"))

    assert_nothing_raised do
      RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: FakePipeline.new, title_generator: title_generator).call(recording_session)
    end

    assert_predicate recording_session.reload, :completed?
    assert_equal RecordingSession::DEFAULT_TITLE, recording_session.title
    assert_equal RecordingSession::DEFAULT_TITLE, recording_session.document.title
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

  test "marks the session failed when audio exceeds maximum duration" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Too long",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    Nodl::Audio::WaveformExtractor.any_instance.stubs(:extract).returns(
      Nodl::Audio::WaveformExtractor::Result.new(peaks: [], duration: PlanLimits.max_recording_duration_seconds + 1)
    )

    assert_raises(Nodl::Error) do
      RecordingSessionProcessor.new(normalizer: FakeNormalizer.new, pipeline: FakePipeline.new).call(recording_session)
    end

    assert_predicate recording_session.reload, :failed?
    assert_includes recording_session.error_message, "can't be longer than #{PlanLimits::MAX_RECORDING_DURATION.in_minutes.to_i} minutes"
  end

  test "triggers telemetry events when processing starts and completes" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Telemetry session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    normalizer = FakeNormalizer.new
    pipeline = FakePipeline.new

    started_events = []
    generated_events = []

    ActiveSupport::Notifications.subscribe("nodl.recording.processing_started") do |*args|
      started_events << ActiveSupport::Notifications::Event.new(*args)
    end

    ActiveSupport::Notifications.subscribe("nodl.document.generated") do |*args|
      generated_events << ActiveSupport::Notifications::Event.new(*args)
    end

    RecordingSessionProcessor.new(normalizer: normalizer, pipeline: pipeline).call(recording_session)

    assert_equal 1, started_events.size
    assert_equal recording_session.id, started_events.first.payload[:recording_session].id

    assert_equal 1, generated_events.size
    assert_equal recording_session.id, generated_events.first.payload[:recording_session].id

    # Privacy: the event must carry only a redacted title preview, never the full title.
    assert_equal "Teleme...", generated_events.first.payload[:redacted_title]
  end

  test "redacted_title exposes only a short preview of the title" do
    assert_equal "Begrüß...", RecordingSessionProcessor.redacted_title("Begrüßung von Lieselotte")
    assert_equal "Sieben...", RecordingSessionProcessor.redacted_title("Sieben!")
    assert_equal "Sechs!", RecordingSessionProcessor.redacted_title("Sechs!")
    assert_equal "Untitled", RecordingSessionProcessor.redacted_title("")
    assert_equal "Untitled", RecordingSessionProcessor.redacted_title(nil)
  end
end

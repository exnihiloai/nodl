require "test_helper"

class RecordingSessionTest < ActiveSupport::TestCase
  test "validates audio attachment and supported content type" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.build(
      creator: user,
      title: "Client call",
      transformer_handle: "default"
    )

    assert_not recording_session.valid?
    assert_includes recording_session.errors[:original_audio], "is required"

    attach_sample_audio(recording_session)
    assert_predicate recording_session, :valid?
  end

  test "allows microphone recording sessions to start without audio" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Live recording",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )

    assert_predicate recording_session, :valid?
  end

  test "rejects unsupported original audio content type" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Notes",
      transformer_handle: "default"
    )
    recording_session.original_audio.attach(
      io: StringIO.new("not audio"),
      filename: "notes.txt",
      content_type: "text/plain"
    )

    assert_not recording_session.valid?
    assert_includes recording_session.errors[:original_audio], "must be an audio file"
  end

  test "completed session creates a document in the same workspace" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Planning",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    recording_session.mark_completed!(
      transcript_text: "Transcript",
      transcript_segments: [ { "start" => 0.0, "end" => 1.0, "speaker" => "Speaker 1", "text" => "Transcript", "words" => [] } ],
      document_content: "# Document",
      work_path: "/tmp/session"
    )

    assert_predicate recording_session.reload, :completed?
    assert_equal "Transcript", recording_session.transcript_text
    assert_equal "Speaker 1", recording_session.transcript_segments.first.fetch("speaker")
    assert_equal "# Document", recording_session.document.content
    assert_equal workspace, recording_session.document.workspace
  end

  test "processing status broadcasts dashboard activity replacement" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Live status",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      [ workspace, :dashboard ],
      target: "dashboard_activity",
      partial: "dashboard/activity",
      locals: has_key(:recording_sessions)
    )
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      recording_session.live_stream,
      target: "live_transcript_panel",
      partial: "recording_sessions/live_transcript_panel",
      locals: has_entries(recording_session: recording_session)
    )

    recording_session.mark_processing!
  end

  test "completed status broadcasts dashboard activity replacement" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Live document",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      [ workspace, :dashboard ],
      target: "dashboard_activity",
      partial: "dashboard/activity",
      locals: has_key(:recording_sessions)
    )
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      recording_session.live_stream,
      target: "live_transcript_panel",
      partial: "recording_sessions/live_transcript_panel",
      locals: has_entries(recording_session: recording_session)
    )

    recording_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/session"
    )
  end
end

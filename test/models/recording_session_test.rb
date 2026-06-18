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
      target: "live_transcript_status",
      partial: "recording_sessions/live_transcript_status",
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

  test "estimated_duration returns precise or estimated values" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.build(
      creator: user,
      title: "Estimating duration",
      transformer_handle: "default"
    )

    # If audio_duration is directly set, prefer it
    recording_session.audio_duration = 123.45
    assert_equal 123.45, recording_session.estimated_duration

    # Otherwise if original_audio is attached, check metadata or estimate
    recording_session.audio_duration = nil
    attach_sample_audio(recording_session)

    # Let's set some metadata
    recording_session.original_audio.blob.update!(metadata: { "duration" => 200.5 })
    assert_equal 200.5, recording_session.estimated_duration

    # If direct duration is missing but bitrate is present
    recording_session.original_audio.blob.update!(metadata: { "bit_rate" => 64000 })
    expected_dur = recording_session.original_audio.blob.byte_size * 8.0 / 64000.0
    assert_equal expected_dur, recording_session.estimated_duration

    # If metadata is missing entirely, fall back to byte size fallback
    recording_session.original_audio.blob.update!(metadata: nil)
    expected_fallback_dur = recording_session.original_audio.blob.byte_size.to_f / 8000.0
    assert_equal expected_fallback_dur, recording_session.estimated_duration
  end

  test "rejects new recording when workspace reached recording limit" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Exercise trial recording limit"
    )

    3.times do |index|
      workspace.recording_sessions.create!(
        creator: user,
        title: "Recording #{index}",
        transformer_handle: "default",
        status: :completed
      ) { |session| attach_sample_audio(session) }
    end

    recording_session = workspace.recording_sessions.build(
      creator: user,
      title: "One too many",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )

    assert_not recording_session.valid?
    assert_includes recording_session.errors[:base], "You've used all 3 recordings included in your test plan."
  end

  test "rejects audio longer than the plan maximum" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Long call",
      transformer_handle: "default"
    )
    attach_sample_audio(recording_session)
    recording_session.stubs(:measured_original_audio_duration).returns(PlanLimits.max_recording_duration_seconds + 1)

    assert_not recording_session.valid?
    assert_includes recording_session.errors[:original_audio], "can't be longer than #{PlanLimits::MAX_RECORDING_DURATION.in_minutes.to_i} minutes"
  end

  test "local_created_at renders created_at in the captured zone" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Vienna note",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording,
      time_zone: "Europe/Vienna"
    )
    recording_session.save!
    recording_session.update_column(:created_at, Time.utc(2026, 6, 8, 18, 49))

    local = recording_session.reload.local_created_at
    assert_equal "Europe/Vienna", local.time_zone.name
    assert_equal "20:49 CEST", local.strftime("%H:%M %Z")
  end

  test "local_created_at falls back to the default zone and drops bogus zones" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Bad zone",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording,
      time_zone: "Not/AZone"
    )
    recording_session.save!

    assert_nil recording_session.time_zone, "unknown zones are normalized away"
    assert_equal recording_session.created_at, recording_session.local_created_at
  end

  test "original audio download filename preserves and sanitizes the attachment filename" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Client Call",
      transformer_handle: "default"
    )
    attach_sample_audio(recording_session, filename: "../Client Call?.MP3")

    assert_equal "client-call.mp3", recording_session.original_audio_download_filename
  end

  test "original audio download filename falls back to recording title and timestamp" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Strategy Review",
      transformer_handle: "default",
      time_zone: "Europe/Vienna"
    )
    recording_session.original_audio.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "rb"),
      filename: "???",
      content_type: "audio/mpeg"
    )
    recording_session.save!
    recording_session.update_column(:created_at, Time.utc(2026, 6, 7, 8, 15))

    assert_equal "strategy-review-20260607-1015.mp3", recording_session.reload.original_audio_download_filename
  end

  test "in-progress recording sessions are excluded from finalized scope and the recording limit" do
    user = create_user_with_workspace
    workspace = user.workspaces.first

    in_progress = 8.times.map do |i|
      workspace.recording_sessions.create!(
        creator: user,
        title: "Live #{i}",
        transformer_handle: "default",
        source_kind: :microphone,
        status: :recording
      )
    end
    completed = workspace.recording_sessions.create!(
      creator: user,
      title: "Finished",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }

    assert_equal [ completed ], workspace.recording_sessions.finalized.to_a
    assert_not_includes workspace.recording_sessions.finalized, in_progress.first
    assert_not workspace.recording_limit_reached?
  end
end

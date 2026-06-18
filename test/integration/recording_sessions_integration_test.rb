require "test_helper"

class RecordingSessionsIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "authenticated user creates a recording session in current workspace" do
    user = create_user_with_workspace(email: "recording-create@example.test")
    post login_path, params: { email: user.email, password: "Valid123" }

    assert_enqueued_with(job: ProcessRecordingSessionJob) do
      post recording_sessions_path, params: {
        recording_session: {
          title: "Client call",
          transformer_handle: "default",
          source_kind: "upload",
          original_audio: Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "audio/mpeg")
        }
      }
    end

    assert_redirected_to dashboard_path
    # Title is encrypted (non-deterministic), so locate the row we just created by recency.
    recording_session = user.workspaces.first.recording_sessions.recent_first.first!
    assert_equal "Client call", recording_session.title
    assert_equal user, recording_session.creator
    assert_equal "default", recording_session.transformer_handle
    assert_predicate recording_session.original_audio, :attached?
  end

  test "authenticated user starts a microphone recording session without audio" do
    user = create_user_with_workspace(email: "recording-live@example.test")
    post login_path, params: { email: user.email, password: "Valid123" }

    assert_no_enqueued_jobs do
      post recording_sessions_path,
           params: {
             recording_session: {
               source_kind: "microphone",
               transformer_handle: "default"
             }
           },
           as: :json
    end

    assert_response :created
    payload = JSON.parse(response.body)
    recording_session = user.workspaces.first.recording_sessions.find(payload.fetch("id"))
    assert_predicate recording_session, :recording?
    assert_equal finalize_recording_session_path(recording_session), payload.fetch("finalize_url")
    assert_equal "LiveTranscriptionChannel", payload.fetch("realtime_channel")
    assert payload.fetch("live_stream_name").present?
  end

  test "finalizes microphone recording by attaching audio and enqueueing processing" do
    user = create_user_with_workspace(email: "recording-finalize@example.test")
    workspace = user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Live call",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    post login_path, params: { email: user.email, password: "Valid123" }

    assert_enqueued_with(job: ProcessRecordingSessionJob, args: [ recording_session.id ]) do
      post finalize_recording_session_path(recording_session),
           params: {
             recording_session: {
               source_kind: "microphone",
               original_audio: Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "audio/mpeg")
             }
           },
           headers: { "ACCEPT" => "application/json" }
    end

    assert_response :accepted
    assert_predicate recording_session.reload, :processing?
    assert_predicate recording_session.original_audio, :attached?
  end

  test "finalize works without realtime preview" do
    user = create_user_with_workspace(email: "recording-finalize-no-segments@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Final only",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    post login_path, params: { email: user.email, password: "Valid123" }

    assert_enqueued_with(job: ProcessRecordingSessionJob, args: [ recording_session.id ]) do
      post finalize_recording_session_path(recording_session),
           params: {
             recording_session: {
               source_kind: "microphone",
               original_audio: Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "audio/mpeg")
             }
           },
           headers: { "ACCEPT" => "application/json" }
    end

    assert_response :accepted
    assert_predicate recording_session.reload, :processing?
  end

  test "rejects unsupported uploads" do
    user = create_user_with_workspace(email: "recording-invalid@example.test")
    post login_path, params: { email: user.email, password: "Valid123" }

    assert_no_enqueued_jobs do
      post recording_sessions_path, params: {
        recording_session: {
          title: "Invalid",
          transformer_handle: "default",
          source_kind: "upload",
          original_audio: Rack::Test::UploadedFile.new(Rails.root.join("README.md"), "text/plain")
        }
      }
    end

    assert_redirected_to dashboard_path
    assert_empty user.workspaces.first.recording_sessions.where(title: "Invalid")
  end

  test "recording session and document pages are workspace scoped" do
    user = create_user_with_workspace(email: "recording-owner@example.test")
    other_user = create_user_with_workspace(email: "recording-other@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Private session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    document = user.workspaces.first.documents.create!(
      recording_session: recording_session,
      transformer_handle: "default",
      title: "Private document",
      content: "# Private",
      generated_at: Time.current
    )

    post login_path, params: { email: other_user.email, password: "Valid123" }

    get recording_session_path(recording_session)
    assert_response :not_found

    get document_path(document)
    assert_response :not_found
  end

  test "completed recording session renders the audio player and clickable transcript" do
    user = create_user_with_workspace(email: "audio-player@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Playable session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.update!(
      status: :completed,
      transcript_text: "Hallo Welt. Wie geht es dir?",
      transcript_segments: [
        { "start" => 0.0, "end" => 1.5, "speaker" => "speaker_1", "text" => "speaker_1: Hallo Welt." },
        { "start" => 1.6, "end" => 3.2, "speaker" => "speaker_1", "text" => "speaker_1: Wie geht es dir?" }
      ],
      waveform_peaks: [ 0.2, 0.6, 1.0, 0.4 ],
      audio_duration: 3.2
    )

    post login_path, params: { email: user.email, password: "Valid123" }
    get recording_session_path(recording_session)

    assert_response :success
    assert_select "[data-controller='audio-player']"
    assert_select "[data-testid='audio-player'] audio[data-audio-player-target='audio']"
    assert_select "[data-audio-player-target='volume'].accent-primary"
    assert_select "[data-audio-player-target='cue']", count: 2
    assert_select "[data-audio-player-target='cue'][data-start='0.0']", text: "Hallo Welt."
    # Single speaker: no speaker-count legend, no per-cue color.
    assert_select "[data-audio-player-target='cue'][data-color]", count: 0
    # Waveform peaks are embedded so the client draws instantly (no audio download).
    assert_select "[data-controller='audio-player'][data-audio-player-peaks-value*='1.0']"
    assert_select "[data-testid='audio-actions-menu']"
    assert_select "[data-testid='audio-actions-menu-button'].btn-ghost.text-primary\\/70"
    assert_select "[data-testid='audio-actions-menu-button'] svg"
    assert_select "[data-testid='audio-actions-menu-button'] svg circle[cx='5'][cy='12']"
    assert_select "[data-testid='audio-actions-menu-button'] svg circle[cx='19'][cy='12']"
    assert_select "[data-testid='download-original-audio']", text: "Download original audio"
  end

  test "multi-speaker transcript shows speaker count and per-speaker colors" do
    user = create_user_with_workspace(email: "audio-multi@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Interview",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.update!(
      status: :completed,
      transcript_text: "Frage. Antwort.",
      transcript_segments: [
        { "start" => 0.0, "end" => 1.0, "speaker" => "speaker_1", "text" => "speaker_1: Frage." },
        { "start" => 1.1, "end" => 2.0, "speaker" => "speaker_2", "text" => "speaker_2: Antwort." }
      ]
    )

    post login_path, params: { email: user.email, password: "Valid123" }
    get recording_session_path(recording_session)

    assert_response :success
    assert_select "[data-audio-player-target='transcript']", text: /#{Regexp.escape(I18n.t("recording_sessions.interactive.speakers", count: 2))}/
    # Each segment becomes its own paragraph because the speaker changes.
    assert_select "[data-audio-player-target='transcript'] p", count: 2
    # Cues carry their speaker color so the highlight can match it.
    assert_select "[data-audio-player-target='cue'][data-color]", count: 2
  end

  test "renders markdown document correctly as HTML" do
    user = create_user_with_workspace(email: "document-render@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Completed session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    document = user.workspaces.first.documents.create!(
      recording_session: recording_session,
      transformer_handle: "default",
      title: "Beautiful doc",
      content: "# Title Header\n\n- Item 1\n- Item 2\n\nThis is **bold** text.",
      generated_at: Time.current
    )

    post login_path, params: { email: user.email, password: "Valid123" }

    get document_path(document)
    assert_response :success
    assert_select "a.btn", text: "Show Recording", href: recording_session_path(recording_session)
    assert_select "a", text: "Back to session", count: 0
    assert_select "article .prose"
    assert_select "h1", text: "Title Header"
    assert_select "ul" do
      assert_select "li", text: "Item 1"
      assert_select "li", text: "Item 2"
    end
    assert_select "strong", text: "bold"
  end

  test "rejects creating a recording when workspace reached recording limit" do
    user = create_user_with_workspace(email: "recording-limit@example.test")
    workspace = user.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Exercise trial recording limit"
    )
    post login_path, params: { email: user.email, password: "Valid123" }

    3.times do |index|
      workspace.recording_sessions.create!(
        creator: user,
        title: "Recording #{index}",
        transformer_handle: "default",
        status: :completed
      ) { |session| attach_sample_audio(session) }
    end

    assert_no_difference -> { workspace.recording_sessions.count } do
      post recording_sessions_path,
           params: {
             recording_session: {
               source_kind: "microphone",
               transformer_handle: "default"
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "recordings included in your test plan"
  end
end

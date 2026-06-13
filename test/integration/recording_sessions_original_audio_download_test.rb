require "test_helper"

class RecordingSessionsOriginalAudioDownloadTest < ActionDispatch::IntegrationTest
  test "original audio download requires authentication" do
    user = create_user_with_workspace(email: "recording-download-auth@example.test")
    recording_session = downloadable_recording_session(user: user)

    get download_original_audio_recording_session_path(recording_session)

    assert_redirected_to login_path
  end

  test "downloads completed recording original audio as an attachment" do
    user = create_user_with_workspace(email: "recording-download@example.test")
    recording_session = downloadable_recording_session(user: user, filename: "Client Call.mp3")
    original = File.binread(Rails.root.join("test", "fixtures", "files", "sample.mp3"))
    login(user)

    get download_original_audio_recording_session_path(recording_session)

    assert_response :success
    assert_equal "audio/mpeg", response.media_type
    assert_match(/attachment; filename="client-call\.mp3"/, response.headers["Content-Disposition"])
    assert_equal original, response.body.b
  end

  test "downloads failed recording when original audio is attached" do
    user = create_user_with_workspace(email: "recording-download-failed@example.test")
    recording_session = downloadable_recording_session(user: user, status: :failed)
    login(user)

    get download_original_audio_recording_session_path(recording_session)

    assert_response :success
    assert_equal "audio/mpeg", response.media_type
  end

  test "original audio download is unavailable while recording or processing" do
    user = create_user_with_workspace(email: "recording-download-active@example.test")
    recording = downloadable_recording_session(user: user, status: :recording)
    processing = downloadable_recording_session(user: user, status: :processing)
    login(user)

    get download_original_audio_recording_session_path(recording)
    assert_redirected_to recording_session_path(recording)

    get download_original_audio_recording_session_path(processing)
    assert_redirected_to recording_session_path(processing)
  end

  test "original audio download is unavailable when storage file is missing" do
    user = create_user_with_workspace(email: "recording-download-missing@example.test")
    recording_session = downloadable_recording_session(user: user)
    blob = recording_session.original_audio.blob
    blob.service.delete(blob.key)
    login(user)

    get download_original_audio_recording_session_path(recording_session)

    assert_redirected_to recording_session_path(recording_session)
  end

  test "original audio download is workspace scoped" do
    owner = create_user_with_workspace(email: "recording-download-owner@example.test")
    intruder = create_user_with_workspace(email: "recording-download-intruder@example.test")
    recording_session = downloadable_recording_session(user: owner)
    login(intruder)

    get download_original_audio_recording_session_path(recording_session)

    assert_response :not_found
  end

  test "admin role alone cannot download another workspace recording" do
    owner = create_user_with_workspace(email: "recording-download-admin-owner@example.test")
    admin = create_user_with_workspace(email: "recording-download-admin@example.test", role: :admin)
    recording_session = downloadable_recording_session(user: owner)
    login(admin)

    get download_original_audio_recording_session_path(recording_session)

    assert_response :not_found
  end

  test "original audio download ignores normalized playback audio" do
    user = create_user_with_workspace(email: "recording-download-original@example.test")
    recording_session = downloadable_recording_session(user: user, filename: "original.webm", content_type: "audio/webm")
    recording_session.normalized_audio.attach(
      io: StringIO.new("normalized mp3 bytes"),
      filename: "normalized.mp3",
      content_type: "audio/mpeg"
    )
    original = File.binread(Rails.root.join("test", "fixtures", "files", "sample.mp3"))
    login(user)

    get download_original_audio_recording_session_path(recording_session)

    assert_response :success
    assert_equal "audio/webm", response.media_type
    assert_match(/attachment; filename="original\.webm"/, response.headers["Content-Disposition"])
    assert_equal original, response.body.b
  end

  test "recording session page hides original audio download while processing" do
    user = create_user_with_workspace(email: "recording-download-disabled@example.test")
    recording_session = downloadable_recording_session(user: user, status: :processing)
    login(user)

    get recording_session_path(recording_session)

    assert_response :success
    assert_select "[data-testid='audio-actions-menu']", count: 0
    assert_select "[data-testid='download-original-audio']", count: 0
  end

  private

  def login(user)
    post login_path, params: { email: user.email, password: "Valid123" }
  end

  def downloadable_recording_session(user:, status: :completed, filename: "sample.mp3", content_type: "audio/mpeg")
    user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Downloadable session",
      transformer_handle: "default",
      status: status
    ) do |session|
      attach_sample_audio(session, filename: filename, content_type: content_type)
    end
  end
end

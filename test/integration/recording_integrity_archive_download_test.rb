require "test_helper"
require "zip"

class RecordingIntegrityArchiveDownloadTest < ActionDispatch::IntegrationTest
  test "integrity archive requires authentication" do
    user = create_user_with_workspace(email: "archive-auth@example.test")
    recording_session = sealed_recording_session(user: user)

    get download_integrity_archive_recording_session_path(recording_session)

    assert_redirected_to login_path
  end

  test "integrity archive is workspace scoped" do
    owner = create_user_with_workspace(email: "archive-owner@example.test")
    intruder = create_user_with_workspace(email: "archive-intruder@example.test")
    recording_session = sealed_recording_session(user: owner)
    login(intruder)

    get download_integrity_archive_recording_session_path(recording_session)

    assert_response :not_found
  end

  test "integrity archive requires enabled feature and sealed record" do
    user = create_user_with_workspace(email: "archive-disabled@example.test")
    recording_session = sealed_recording_session(user: user, enabled: false)
    login(user)

    get download_integrity_archive_recording_session_path(recording_session)

    assert_redirected_to recording_session_path(recording_session)
  end

  test "downloads zip containing original audio and certificate" do
    user = create_user_with_workspace(email: "archive-download@example.test")
    recording_session = sealed_recording_session(user: user, filename: "Original Call.mp3")
    original = recording_session.original_audio.download
    login(user)

    get download_integrity_archive_recording_session_path(recording_session)

    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/attachment; filename="original-call-integrity-archive\.zip"/, response.headers["Content-Disposition"])

    Zip::File.open_buffer(response.body) do |zip|
      names = zip.map(&:name)
      assert_includes names, "original-call.mp3"
      assert_includes names, "integrity-certificate.json"
      assert_equal original, zip.read("original-call.mp3").b
      certificate = JSON.parse(zip.read("integrity-certificate.json"))
      assert_equal recording_session.id, certificate.fetch("recording_session_id")
      assert_equal "original-call.mp3", certificate.fetch("original_filename")
      assert_equal true, certificate.fetch("integrity_hash_matches_exported_file")
      assert_equal RecordingIntegrityRecord::STATUS_SEALED, certificate.fetch("integrity_tsa_status")
      assert certificate.fetch("integrity_tsa_proof_blob").present?
    end
  end

  test "certificate reports mismatch when stored hash differs from bundled audio" do
    user = create_user_with_workspace(email: "archive-mismatch@example.test")
    recording_session = sealed_recording_session(user: user, hash_sha256: "0" * 64)
    login(user)

    get download_integrity_archive_recording_session_path(recording_session)

    assert_response :success
    Zip::File.open_buffer(response.body) do |zip|
      certificate = JSON.parse(zip.read("integrity-certificate.json"))
      assert_equal false, certificate.fetch("integrity_hash_matches_exported_file")
    end
  end

  private

  def login(user)
    post login_path, params: { email: user.email, password: "Valid123" }
  end

  def sealed_recording_session(user:, enabled: true, filename: "sample.mp3", hash_sha256: nil)
    user.update!(integrity_sealing_enabled: enabled)
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Archive session",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session, filename: filename, content_type: "audio/mpeg") }
    recording_session.create_integrity_record!(
      hash_sha256: hash_sha256 || Digest::SHA256.hexdigest(recording_session.original_audio.download),
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: RecordingIntegrityRecord::STATUS_SEALED,
      tsa_provider: "rfc3161_freetsa",
      tsa_authority: "freetsa.org",
      tsa_proof_format: RecordingIntegrityRecord::PROOF_FORMAT_RFC3161,
      tsa_proof_blob: Base64.strict_encode64("proof"),
      tsa_timestamp: Time.current
    )
    recording_session
  end
end

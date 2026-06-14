require "test_helper"
require "base64"

class RecordingIntegrityIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "enabled user upload enqueues integrity sealing after recording creation" do
    user = create_user_with_workspace(email: "recording-create-integrity@example.test")
    user.update!(integrity_sealing_enabled: true)
    login(user)

    assert_enqueued_with(job: ProcessRecordingSessionJob) do
      assert_enqueued_with(job: SealRecordingIntegrityJob) do
        post recording_sessions_path, params: {
          recording_session: {
            title: "Client call",
            transformer_handle: "default",
            source_kind: "upload",
            original_audio: Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "audio/mpeg")
          }
        }
      end
    end

    assert_redirected_to dashboard_path
  end

  test "enabled user microphone finalize enqueues integrity sealing" do
    user = create_user_with_workspace(email: "recording-finalize-integrity@example.test")
    user.update!(integrity_sealing_enabled: true)
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Live call",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    login(user)

    assert_enqueued_with(job: ProcessRecordingSessionJob, args: [ recording_session.id ]) do
      assert_enqueued_with(job: SealRecordingIntegrityJob, args: [ recording_session.id ]) do
        post finalize_recording_session_path(recording_session),
             params: {
               recording_session: {
                 source_kind: "microphone",
                 original_audio: Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "audio/mpeg")
               }
             },
             headers: { "ACCEPT" => "application/json" }
      end
    end

    assert_response :accepted
  end

  test "recording session page shows integrity status only when enabled" do
    disabled_user = create_user_with_workspace(email: "integrity-hidden@example.test")
    hidden_session = completed_recording(disabled_user, title: "Hidden integrity")

    login(disabled_user)
    get recording_session_path(hidden_session)
    assert_response :success
    assert_select "[data-testid='integrity-status']", count: 0

    delete logout_path
    enabled_user = create_user_with_workspace(email: "integrity-visible@example.test")
    enabled_user.update!(integrity_sealing_enabled: true)
    visible_session = completed_recording(enabled_user, title: "Visible integrity")
    visible_session.create_integrity_record!(
      hash_sha256: Digest::SHA256.hexdigest(visible_session.original_audio.download),
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: RecordingIntegrityRecord::STATUS_SEALED,
      tsa_provider: "rfc3161_freetsa",
      tsa_authority: "freetsa.org",
      tsa_proof_format: RecordingIntegrityRecord::PROOF_FORMAT_RFC3161,
      tsa_proof_blob: Base64.strict_encode64("proof")
    )

    login(enabled_user)
    get recording_session_path(visible_session)

    assert_response :success
    assert_select "[data-testid='integrity-status']"
    assert_select "[data-testid='integrity-status-badge']", text: /secured/i
    assert_select "[data-testid='integrity-status-details']"
    assert_select "[data-testid='integrity-status'] button[data-disclosure-target='trigger']"
    assert_select "[data-testid='download-integrity-archive']"
    assert_select "[data-testid='download-integrity-archive-menu']"
  end

  private

  def login(user)
    post login_path, params: { email: user.email, password: "Valid123" }
  end

  def completed_recording(user, title:)
    user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: title,
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }
  end
end

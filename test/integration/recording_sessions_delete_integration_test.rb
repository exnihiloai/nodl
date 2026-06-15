require "test_helper"

class RecordingSessionsDeleteIntegrationTest < ActionDispatch::IntegrationTest
  test "workspace member can delete finalized recording sessions" do
    owner = create_user_with_workspace(email: "recording-delete-owner@example.test")
    workspace = owner.workspaces.first
    member = create_user_with_workspace(email: "recording-delete-member@example.test")
    Membership.create!(user: member, workspace: workspace, role: :member)
    post login_path, params: { email: member.email, password: "Valid123" }
    post switch_workspace_path(workspace)

    %i[pending processing completed failed].each do |status|
      recording_session = workspace.recording_sessions.create!(
        creator: owner,
        title: "#{status} delete",
        transformer_handle: "default",
        status: status
      ) { |session| attach_sample_audio(session) }

      assert_difference -> { RecordingSession.count }, -1 do
        delete recording_session_path(recording_session)
      end

      assert_redirected_to dashboard_path
      assert_equal %(Recording "#{status} delete" was permanently deleted.), flash[:notice]
    end
  end

  test "cannot delete a live recording session through finalized destroy scope" do
    user = create_user_with_workspace(email: "recording-delete-live@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Still recording",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    post login_path, params: { email: user.email, password: "Valid123" }

    assert_no_difference -> { RecordingSession.count } do
      delete recording_session_path(recording_session)
    end

    assert_response :not_found
  end

  test "cannot delete another workspace recording session" do
    owner = create_user_with_workspace(email: "recording-delete-scope-owner@example.test")
    intruder = create_user_with_workspace(email: "recording-delete-scope-intruder@example.test")
    recording_session = owner.workspaces.first.recording_sessions.create!(
      creator: owner,
      title: "Private delete",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }
    post login_path, params: { email: intruder.email, password: "Valid123" }

    assert_no_difference -> { RecordingSession.count } do
      delete recording_session_path(recording_session)
    end

    assert_response :not_found
  end

  test "deleting a completed recording removes dependents and frees recording quota" do
    user = create_user_with_workspace(email: "recording-delete-complete@example.test")
    workspace = user.workspaces.first
    (PlanLimits::MAX_RECORDINGS - 1).times do |index|
      workspace.recording_sessions.create!(
        creator: user,
        title: "Quota #{index}",
        transformer_handle: "default",
        status: :completed
      ) { |session| attach_sample_audio(session) }
    end
    recording_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Complete delete",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }
    recording_session.normalized_audio.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "rb"),
      filename: "normalized.mp3",
      content_type: "audio/mpeg"
    )
    document = workspace.documents.create!(
      recording_session: recording_session,
      transformer_handle: "default",
      title: "Complete delete",
      content: "# Document",
      generated_at: Time.current
    )
    integrity_record = recording_session.create_integrity_record!(
      hash_sha256: "a" * 64,
      hash_algorithm: "sha256",
      hashed_at: Time.current,
      tsa_status: RecordingIntegrityRecord::STATUS_SEALED,
      tsa_provider: "rfc3161_freetsa",
      tsa_proof_format: RecordingIntegrityRecord::PROOF_FORMAT_RFC3161,
      tsa_proof_blob: "proof"
    )
    post login_path, params: { email: user.email, password: "Valid123" }

    assert workspace.reload.recording_limit_reached?
    assert_destroy_removes_recording_data(recording_session, document, integrity_record)
    assert_not workspace.reload.recording_limit_reached?
  end

  test "repeat delete reports the recording is already gone" do
    user = create_user_with_workspace(email: "recording-delete-repeat@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Gone",
      transformer_handle: "default",
      status: :failed
    ) { |session| attach_sample_audio(session) }
    post login_path, params: { email: user.email, password: "Valid123" }

    delete recording_session_path(recording_session)
    delete recording_session_path(recording_session)

    assert_redirected_to dashboard_path
    assert_equal "Recording no longer exists.", flash[:notice]
  end

  test "detail page delete redirects to dashboard" do
    user = create_user_with_workspace(email: "recording-delete-detail@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Detail delete",
      transformer_handle: "default",
      status: :failed
    ) { |session| attach_sample_audio(session) }
    post login_path, params: { email: user.email, password: "Valid123" }

    delete recording_session_path(recording_session)

    assert_redirected_to dashboard_path
    assert_equal %(Recording "Detail delete" was permanently deleted.), flash[:notice]
  end

  test "dashboard delete turbo stream restores record hero when quota opens up" do
    user = create_user_with_workspace(email: "recording-delete-quota@example.test")
    workspace = user.workspaces.first
    PlanLimits::MAX_RECORDINGS.times do |index|
      workspace.recording_sessions.create!(
        creator: user,
        title: "Quota #{index}",
        transformer_handle: "default",
        status: :completed
      ) { |session| attach_sample_audio(session) }
    end
    recording_session = workspace.recording_sessions.finalized.order(:created_at).last
    post login_path, params: { email: user.email, password: "Valid123" }

    assert workspace.reload.recording_limit_reached?

    delete recording_session_path(recording_session), as: :turbo_stream

    assert_response :success
    assert_not workspace.reload.recording_limit_reached?
    assert_includes response.body, 'data-testid="recording-form"'
    assert_not_includes response.body, 'data-testid="recording-limit-reached"'
    assert_includes response.body, 'target="dashboard_record_hero"'
  end

  private

  def assert_destroy_removes_recording_data(recording_session, document, integrity_record)
    assert_difference -> { RecordingSession.count }, -1 do
      assert_difference -> { Document.count }, -1 do
        assert_difference -> { RecordingIntegrityRecord.count }, -1 do
          delete recording_session_path(recording_session)
        end
      end
    end

    assert_not Document.exists?(document.id)
    assert_not RecordingIntegrityRecord.exists?(integrity_record.id)
    assert_empty ActiveStorage::Attachment.where(record_type: "RecordingSession", record_id: recording_session.id)
  end
end

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
    recording_session = user.workspaces.first.recording_sessions.find_by!(title: "Client call")
    assert_equal user, recording_session.creator
    assert_equal "default", recording_session.transformer_handle
    assert_predicate recording_session.original_audio, :attached?
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
end

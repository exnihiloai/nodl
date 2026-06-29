require "test_helper"

class RecordingSessionsFinalizeValidationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "rejects finalizing microphone recording with empty audio" do
    recording_session = create_recording_session(email: "recording-finalize-empty@example.test")

    Tempfile.create([ "empty-recording", ".m4a" ]) do |file|
      assert_no_enqueued_jobs do
        post finalize_recording_session_path(recording_session),
             params: finalize_params(file.path, "audio/mp4", "empty.m4a"),
             headers: { "ACCEPT" => "application/json" }
      end
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("error"), "must contain recorded audio"
    assert_predicate recording_session.reload, :recording?
  end

  test "accepts non-empty microphone audio for background processing" do
    recording_session = create_recording_session(email: "recording-finalize-interrupted@example.test")

    Tempfile.create([ "interrupted-recording", ".webm" ]) do |file|
      file.write("not a real webm")
      file.flush

      assert_enqueued_with(job: ProcessRecordingSessionJob, args: [ recording_session.id ]) do
        post finalize_recording_session_path(recording_session),
             params: finalize_params(file.path, "audio/webm", "interrupted.webm"),
             headers: { "ACCEPT" => "application/json" }
      end
    end

    assert_response :accepted
    assert_predicate recording_session.reload, :processing?
  end

  test "turbo stream finalize replaces dashboard activity with processing row" do
    recording_session = create_recording_session(email: "recording-finalize-stream@example.test", title: "Live stream update")

    assert_enqueued_with(job: ProcessRecordingSessionJob, args: [ recording_session.id ]) do
      post finalize_recording_session_path(recording_session),
           params: finalize_params(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "audio/mpeg", "sample.mp3"),
           as: :turbo_stream
    end

    assert_response :accepted
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, %(target="dashboard_activity")
    assert_includes response.body, %(data-status="processing")
    assert_includes response.body, %(data-controller="processing-progress")
    assert_predicate recording_session.reload, :processing?
  end

  private

  def create_recording_session(email:, title: "Interrupted")
    user = create_user_with_workspace(email: email)
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: title,
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    post login_path, params: { email: user.email, password: "Valid123" }
    recording_session
  end

  def finalize_params(path, content_type, original_filename)
    {
      recording_session: {
        source_kind: "microphone",
        original_audio: Rack::Test::UploadedFile.new(path, content_type, original_filename: original_filename)
      }
    }
  end
end

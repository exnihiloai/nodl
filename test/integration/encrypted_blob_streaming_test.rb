require "test_helper"

# Verifies EncryptedDisk blobs are served through the streaming controller with
# HTTP Range support — the operational hinge for audio playback/seek.
class EncryptedBlobStreamingTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @user = create_user_with_workspace(email: "blob-stream@example.test")
    @recording = @user.workspaces.first.recording_sessions.create!(
      creator: @user,
      title: "Streamable",
      transformer_handle: "default",
      status: :completed
    ) { |session| attach_sample_audio(session) }
    @original = File.binread(Rails.root.join("test", "fixtures", "files", "sample.mp3"))
    post login_path, params: { email: @user.email, password: "Valid123" }
  end

  teardown do
    @recording&.workspace&.destroy
    @user&.destroy
  end

  test "rails_blob_path streams decrypted bytes and honors range requests" do
    blob_path = rails_blob_path(@recording.playback_audio, only_path: true)

    get blob_path
    assert_response :redirect
    streaming_path = URI.parse(response.headers["Location"]).path

    get streaming_path
    assert_response :success
    assert_equal @original, response.body.b

    get streaming_path, headers: { "Range" => "bytes=0-7" }
    assert_response :partial_content
    assert_equal @original.byteslice(0, 8), response.body.b
    assert_match(/bytes/, response.headers["Content-Range"].to_s)
  end
end

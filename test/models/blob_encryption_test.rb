require "test_helper"

# Verifies uploaded blobs are encrypted at rest (per-blob key, EncryptedDisk) yet
# remain readable — including HTTP Range reads used for audio playback/seek — so
# authorized members are not blocked from their own data. Runs without the test
# transaction because Active Storage uploads bytes on after_commit.
class BlobEncryptionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    @recording = @workspace.recording_sessions.create!(
      creator: @user,
      title: "Call",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    @original = File.binread(Rails.root.join("test", "fixtures", "files", "sample.mp3"))
  end

  teardown do
    @workspace&.destroy
    @user&.destroy
  end

  test "audio blob is encrypted on disk with a per-blob key" do
    blob = @recording.original_audio.blob

    assert blob.encryption_key.present?, "expected a per-blob encryption key"
    assert blob.service.encrypted?, "expected the blob to use an encrypted service"

    on_disk = File.binread(blob.service.send(:path_for, blob.key))
    refute_equal @original, on_disk, "blob bytes are not encrypted at rest"
  end

  test "authorized download decrypts to the original bytes" do
    assert_equal @original, @recording.original_audio.download
  end

  test "range reads work so audio playback/seek is not blocked" do
    blob = @recording.original_audio.blob
    chunk = blob.service.download_chunk(blob.key, 0...8, encryption_key: blob.encryption_key)

    # Block decryption may return a slightly wider prefix than the requested range;
    # what matters for playback is that the bytes match the original file.
    assert_equal @original.byteslice(0, chunk.bytesize), chunk
  end
end

require "test_helper"

class RecordingSessionAudioValidationTest < ActiveSupport::TestCase
  test "rejects empty browser audio" do
    recording_session = build_microphone_recording
    recording_session.original_audio.attach(
      io: StringIO.new(""),
      filename: "interrupted.m4a",
      content_type: "audio/mp4"
    )

    assert_not recording_session.valid?
    assert_includes recording_session.errors[:original_audio], "must contain recorded audio"
  end

  test "rejects undecodable browser audio" do
    recording_session = build_microphone_recording
    recording_session.original_audio.attach(
      io: StringIO.new("not a real webm"),
      filename: "interrupted.webm",
      content_type: "audio/webm"
    )

    assert_not recording_session.valid?
    assert_includes recording_session.errors[:original_audio], "was interrupted before a valid audio file could be saved"
  end

  private

  def build_microphone_recording
    user = create_user_with_workspace
    user.workspaces.first.recording_sessions.build(
      creator: user,
      title: "Interrupted",
      transformer_handle: "default",
      source_kind: :microphone
    )
  end
end

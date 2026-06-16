require "test_helper"

class ProcessRecordingSessionJobTest < ActiveJob::TestCase
  test "delegates to the recording session processor" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Job session",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    processor = mock
    processor.expects(:call).with(recording_session)
    RecordingSessionProcessor.expects(:new).returns(processor)

    ProcessRecordingSessionJob.perform_now(recording_session.id)
  end

  test "marks session failed when processor setup fails" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Failed job",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    RecordingSessionProcessor.expects(:new).raises(NameError, "uninitialized constant RecordingSessionProcessor")

    assert_raises(NameError) do
      ProcessRecordingSessionJob.perform_now(recording_session.id)
    end

    assert_predicate recording_session.reload, :failed?
    assert_includes recording_session.error_message, "uninitialized constant RecordingSessionProcessor"
  end

  test "does not overwrite a processor-sanitized failure message" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Failed job",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    processor = Object.new
    processor.define_singleton_method(:call) do |session|
      session.mark_failed!(RecordingSessionProcessor::INVALID_AUDIO_MESSAGE)
      raise Nodl::ValidationError, "Audio could not be normalized with ffmpeg: raw stderr"
    end
    RecordingSessionProcessor.expects(:new).returns(processor)

    assert_raises(Nodl::ValidationError) do
      ProcessRecordingSessionJob.perform_now(recording_session.id)
    end

    assert_equal RecordingSessionProcessor::INVALID_AUDIO_MESSAGE, recording_session.reload.error_message
  end

  test "exits when the recording session has been deleted" do
    RecordingSessionProcessor.expects(:new).never

    assert_nothing_raised do
      ProcessRecordingSessionJob.perform_now(-1)
    end
  end
end

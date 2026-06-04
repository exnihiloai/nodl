require "test_helper"
require "nodl/error"
require "nodl/transcription/gemini_transcriber"

class TranscribeSegmentJobTest < ActiveJob::TestCase
  test "transcribes a live segment, stores ordered preview text, and broadcasts" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Live job",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    blob = create_segment_blob
    transcriber = mock
    transcriber.expects(:transcribe).with do |audio:, model:, preview:|
      audio.mime_type == "audio/mpeg" && model.present? && preview
    end.returns(Nodl::Transcription::Result.new(text: "Live preview text", file_uri: "files/segment"))
    Nodl::Transcription::GeminiTranscriber.expects(:new).returns(transcriber)
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      recording_session.live_stream,
      target: "live_transcript_segments",
      partial: "recording_sessions/live_transcript_segments",
      locals: { segments: [ "Live preview text" ] }
    )

    TranscribeSegmentJob.perform_now(recording_session.id, blob.signed_id, 0)

    assert_equal [ "Live preview text" ], recording_session.live_transcript_segments
    assert_raises(ActiveRecord::RecordNotFound) { blob.reload }
  end

  test "segment transcription failures do not fail the recording session" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Live failure",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    blob = create_segment_blob
    transcriber = mock
    transcriber.expects(:transcribe).raises(Nodl::GeminiError, "temporary")
    Nodl::Transcription::GeminiTranscriber.expects(:new).returns(transcriber)
    Turbo::StreamsChannel.expects(:broadcast_replace_to).never

    assert_nothing_raised do
      TranscribeSegmentJob.perform_now(recording_session.id, blob.signed_id, 1)
    end

    assert_predicate recording_session.reload, :recording?
    assert_empty recording_session.live_transcript_segments
  end

  test "live transcript segments are ordered by index when jobs finish out of order" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Out of order",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    first_blob = create_segment_blob(filename: "segment-2.mp3")
    second_blob = create_segment_blob(filename: "segment-1.mp3")
    transcriber = mock
    transcriber.expects(:transcribe).twice.returns(
      Nodl::Transcription::Result.new(text: "Second segment", file_uri: "files/segment-2"),
      Nodl::Transcription::Result.new(text: "First segment", file_uri: "files/segment-1")
    )
    Nodl::Transcription::GeminiTranscriber.expects(:new).twice.returns(transcriber)
    Turbo::StreamsChannel.stubs(:broadcast_replace_to)

    TranscribeSegmentJob.perform_now(recording_session.id, first_blob.signed_id, 2)
    TranscribeSegmentJob.perform_now(recording_session.id, second_blob.signed_id, 1)

    assert_equal [ "First segment", "Second segment" ], recording_session.live_transcript_segments
  end

  private

  def create_segment_blob(filename: "segment.mp3")
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "rb"),
      filename: filename,
      content_type: "audio/mpeg"
    )
  end
end

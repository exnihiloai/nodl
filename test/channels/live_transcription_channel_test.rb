require "test_helper"
require "base64"

class LiveTranscriptionChannelTest < ActionCable::Channel::TestCase
  class FakeRealtimeClient
    attr_reader :audio_frames, :target_streaming_delay_ms

    def initialize(target_streaming_delay_ms:)
      @target_streaming_delay_ms = target_streaming_delay_ms
      @audio_frames = []
      @closed = false
    end

    def start(&handler)
      @handler = handler
    end

    def send_audio(frame)
      @audio_frames << frame
    end

    def emit(event)
      @handler.call(event)
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end

  setup do
    @clients = []
    LiveTranscriptionChannel.realtime_client_factory = ->(target_streaming_delay_ms:) {
      FakeRealtimeClient.new(target_streaming_delay_ms: target_streaming_delay_ms).tap { |client| @clients << client }
    }
  end

  teardown do
    LiveTranscriptionChannel.realtime_client_factory = -> { Nodl::Providers::MistralRealtimeClient.new }
  end

  test "rejects unauthenticated subscriptions" do
    stub_connection current_user: nil, current_workspace: nil

    subscribe(recording_session_id: 123)

    assert subscription.rejected?
  end

  test "rejects sessions outside the current workspace" do
    user = create_user_with_workspace(email: "live-channel-owner@example.test")
    other_user = create_user_with_workspace(email: "live-channel-other@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Private live",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    stub_connection current_user: other_user, current_workspace: other_user.workspaces.first

    subscribe(recording_session_id: recording_session.id)

    assert subscription.rejected?
  end

  test "rejects non-recording sessions" do
    user = create_user_with_workspace(email: "live-channel-processing@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Processing live",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :processing
    ) { |session| attach_sample_audio(session) }
    stub_connection current_user: user, current_workspace: user.workspaces.first

    subscribe(recording_session_id: recording_session.id)

    assert subscription.rejected?
  end

  test "forwards audio frames and transmits text deltas" do
    user = create_user_with_workspace(email: "live-channel@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Live",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    stub_connection current_user: user, current_workspace: user.workspaces.first

    subscribe(recording_session_id: recording_session.id)

    assert subscription.confirmed?
    assert_equal [ LiveTranscriptionChannel::FAST_DELAY_MS, LiveTranscriptionChannel::SLOW_DELAY_MS ], @clients.map(&:target_streaming_delay_ms)
    perform :receive, { "type" => "audio", "audio" => Base64.strict_encode64("pcm") }
    assert_equal [ Base64.strict_encode64("pcm") ], @clients.first.audio_frames
    assert_equal [ Base64.strict_encode64("pcm") ], @clients.second.audio_frames

    @clients.first.emit({ "type" => "transcription.text.delta", "text" => "Hallo" })
    assert_equal({ "type" => "fast_delta", "text" => "Hallo" }, transmissions.last)

    @clients.second.emit({ "type" => "transcription.text.delta", "text" => "Hallo" })
    assert_equal({ "type" => "slow_delta", "text" => "Hallo" }, transmissions.last)
  end

  test "transmits realtime errors" do
    user = create_user_with_workspace(email: "live-channel-error@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Live error",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    stub_connection current_user: user, current_workspace: user.workspaces.first
    subscribe(recording_session_id: recording_session.id)

    @clients.first.emit({ "type" => "error", "error" => { "message" => "Failed to negotiate connection!" } })

    assert_equal({ "type" => "error", "stream" => "fast", "error" => "Failed to negotiate connection!" }, transmissions.last)
  end

  test "closes realtime client on stop" do
    user = create_user_with_workspace(email: "live-channel-stop@example.test")
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Live stop",
      transformer_handle: "default",
      source_kind: :microphone,
      status: :recording
    )
    stub_connection current_user: user, current_workspace: user.workspaces.first
    subscribe(recording_session_id: recording_session.id)

    perform :receive, { "type" => "stop" }

    assert_predicate @clients.first, :closed?
    assert_predicate @clients.second, :closed?
  end
end

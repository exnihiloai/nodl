require "nodl/providers/mistral_realtime_client"

class LiveTranscriptionChannel < ApplicationCable::Channel
  FAST_DELAY_MS = ENV.fetch("NODL_VOXTRAL_REALTIME_FAST_DELAY_MS", "240").to_i
  SLOW_DELAY_MS = ENV.fetch("NODL_VOXTRAL_REALTIME_SLOW_DELAY_MS", "2400").to_i

  class_attribute :realtime_client_factory, default: ->(target_streaming_delay_ms:) {
    Nodl::Providers::MistralRealtimeClient.new(target_streaming_delay_ms: target_streaming_delay_ms)
  }

  def subscribed
    return reject unless current_user && current_workspace

    @recording_session = current_workspace.recording_sessions.find_by(id: params[:recording_session_id])
    return reject unless @recording_session&.recording?

    @fast_client = realtime_client_factory.call(target_streaming_delay_ms: FAST_DELAY_MS)
    @slow_client = realtime_client_factory.call(target_streaming_delay_ms: SLOW_DELAY_MS)
    @fast_client.start do |event|
      handle_realtime_event(event, stream: "fast")
    end
    @slow_client.start do |event|
      handle_realtime_event(event, stream: "slow")
    end
    transmit({ type: "connected", fast_delay_ms: FAST_DELAY_MS, slow_delay_ms: SLOW_DELAY_MS })
  rescue Nodl::ConfigurationError => error
    reject
    Rails.logger.warn("Live transcription rejected: #{error.message}")
  end

  def receive(data)
    return unless @recording_session&.recording?

    case data["type"]
    when "audio"
      @fast_client&.send_audio(data["audio"])
      @slow_client&.send_audio(data["audio"])
    when "stop"
      close_realtime_clients
    end
  rescue Nodl::MistralError => error
    transmit({ type: "error", error: error.message })
  end

  def unsubscribed
    close_realtime_clients
  end

  private

  def handle_realtime_event(event, stream:)
    event_type = event["type"].to_s
    case event_type
    when "transcription.text.delta"
      transmit({ type: "#{stream}_delta", text: event["text"].to_s })
    when "transcription.done"
      transmit({ type: "#{stream}_done" })
    when "session.created", "session.updated"
      transmit({ type: "#{stream}_connected" })
    else
      transmit({ type: "error", stream: stream, error: realtime_error_message(event) }) if event_type == "error"
    end
  end

  def realtime_error_message(event)
    error = event["error"]
    return error["message"] if error.is_a?(Hash) && error["message"].present?
    return error if error.is_a?(String) && error.present?

    "Realtime transcription failed."
  end

  def close_realtime_clients
    @fast_client&.close
    @slow_client&.close
    @fast_client = nil
    @slow_client = nil
  end
end

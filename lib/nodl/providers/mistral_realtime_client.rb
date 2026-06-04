require "base64"
require "json"
require "uri"
require_relative "../error"

module Nodl
  module Providers
    class MistralRealtimeClient
      API_HOST = "api.mistral.ai"
      REALTIME_PATH = "/v1/audio/transcriptions/realtime"
      DEFAULT_MODEL = "voxtral-mini-transcribe-realtime-2602"

      def initialize(api_key: ENV["MISTRAL_API_KEY"], model: ENV.fetch("NODL_VOXTRAL_REALTIME_MODEL", DEFAULT_MODEL), target_streaming_delay_ms: nil)
        @api_key = api_key.to_s.strip
        @model = model
        @target_streaming_delay_ms = target_streaming_delay_ms
        @audio_queue = Queue.new
        @closed = false
        raise ConfigurationError, "MISTRAL_API_KEY is required." if @api_key.empty?
      end

      def start(&event_handler)
        @thread = Thread.new { run(event_handler) }
      end

      def send_audio(base64_audio)
        return if closed?

        audio_queue << Base64.strict_decode64(base64_audio.to_s)
      rescue ArgumentError => error
        raise MistralError, "Invalid realtime audio frame: #{error.message}"
      end

      def close
        @closed = true
        audio_queue << :close
        @connection&.close
        @thread&.join(1)
      rescue StandardError
        nil
      end

      private

      attr_reader :api_key, :model, :target_streaming_delay_ms, :audio_queue

      def closed?
        @closed
      end

      def run(event_handler)
        require "async"
        require "async/http/endpoint"
        require "async/http/protocol/http11"
        require "async/websocket/client"

        Async do
          endpoint = Async::HTTP::Endpoint.parse(realtime_url, protocol: Async::HTTP::Protocol::HTTP11)
          @connection = Async::WebSocket::Client.connect(
            endpoint,
            headers: { "Authorization" => "Bearer #{api_key}" }
          )
          read_handshake(event_handler)
          send_session_update
          start_audio_writer
          read_events(event_handler)
        ensure
          @connection&.close
        end
      rescue StandardError => error
        event_handler.call({ "type" => "error", "error" => { "message" => error.message } }) if event_handler
      end

      def realtime_url
        "wss://#{API_HOST}#{REALTIME_PATH}?#{URI.encode_www_form(model: model)}"
      end

      def read_handshake(event_handler)
        loop do
          event = read_event
          event_handler.call(event) if event_handler
          break if event["type"] == "session.created"

          raise MistralError, event.dig("error", "message").presence || "Realtime transcription failed." if event["type"] == "error"
        end
      end

      def send_session_update
        @connection.write(JSON.dump(
          type: "session.update",
          session: {
            audio_format: {
              encoding: "pcm_s16le",
              sample_rate: 16_000
            }
          }.tap do |session|
            session[:target_streaming_delay_ms] = target_streaming_delay_ms if target_streaming_delay_ms
          end
        ))
      end

      def start_audio_writer
        Thread.new do
          loop do
            frame = audio_queue.pop
            break if frame == :close

            @connection.write(JSON.dump(
              type: "input_audio.append",
              audio: Base64.strict_encode64(frame)
            ))
          end
        rescue StandardError
          nil
        end
      end

      def read_events(event_handler)
        loop do
          payload = read_event
          event_handler.call(payload) if event_handler
          break if payload["type"] == "transcription.done" || payload["type"] == "error"
        end
      end

      def read_event
        message = @connection.read
        raise MistralError, "Realtime transcription socket closed." unless message

        JSON.parse(message.to_str)
      end
    end
  end
end

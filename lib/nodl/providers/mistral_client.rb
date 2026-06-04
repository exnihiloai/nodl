require "json"
require "net/http"
require "pathname"
require "uri"
require_relative "../error"

module Nodl
  module Providers
    class MistralClient
      API_HOST = "api.mistral.ai"
      TRANSCRIPTIONS_PATH = "/v1/audio/transcriptions"

      def initialize(api_key: ENV["MISTRAL_API_KEY"])
        @api_key = api_key.to_s.strip
        raise ConfigurationError, "MISTRAL_API_KEY is required." if @api_key.empty?
      end

      def transcribe(path:, model:, diarize:, timestamp_granularities:, language: nil, context_bias: nil)
        file = Pathname.new(path.to_s)
        uri = URI::HTTPS.build(host: API_HOST, path: TRANSCRIPTIONS_PATH)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{api_key}"
        file_handle = File.open(file, "rb")
        request.set_form(multipart_fields(file_handle, model, diarize, timestamp_granularities, language, context_bias), "multipart/form-data")

        response = perform(uri, request)
        ensure_success!(response)
        parse_json(response)
      ensure
        file_handle&.close
      end

      protected

      def perform(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end
      end

      private

      attr_reader :api_key

      def multipart_fields(file_handle, model, diarize, timestamp_granularities, language, context_bias)
        fields = [
          [ "model", model ],
          [ "diarize", diarize ? "true" : "false" ],
          [ "timestamp_granularities", timestamp_granularities.first ],
          [ "file", file_handle ]
        ]
        fields << [ "language", language ] if language.present?
        Array(context_bias).compact_blank.each do |bias|
          fields << [ "context_bias[]", bias ]
        end
        fields
      end

      def ensure_success!(response)
        return if response.code.to_i.between?(200, 299)

        raise MistralError, "Mistral API request failed with HTTP #{response.code}: #{response.body}"
      end

      def parse_json(response)
        JSON.parse(response.body)
      rescue JSON::ParserError => error
        raise MistralError, "Mistral API returned invalid JSON: #{error.message}"
      end
    end
  end
end

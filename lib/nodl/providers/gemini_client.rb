require "json"
require "net/http"
require "pathname"
require "uri"
require_relative "../error"

module Nodl
  module Providers
    class GeminiClient
      API_HOST = "generativelanguage.googleapis.com"

      def initialize(api_key: ENV["GEMINI_API_KEY"])
        @api_key = api_key.to_s.strip
        raise ConfigurationError, "GEMINI_API_KEY is required." if @api_key.empty?
      end

      def upload_file(path:, mime_type:, display_name:)
        file = Pathname.new(path.to_s)
        start_uri = URI::HTTPS.build(host: API_HOST, path: "/upload/v1beta/files")
        start_request = Net::HTTP::Post.new(start_uri)
        apply_json_headers(start_request)
        start_request["X-Goog-Upload-Protocol"] = "resumable"
        start_request["X-Goog-Upload-Command"] = "start"
        start_request["X-Goog-Upload-Header-Content-Length"] = file.size.to_s
        start_request["X-Goog-Upload-Header-Content-Type"] = mime_type
        start_request.body = JSON.dump(file: { display_name: display_name })

        start_response = perform(start_uri, start_request)
        ensure_success!(start_response)

        upload_url = start_response["x-goog-upload-url"]
        raise GeminiError, "Gemini upload did not return an upload URL." if upload_url.to_s.empty?

        upload_uri = URI(upload_url)
        upload_request = Net::HTTP::Post.new(upload_uri)
        upload_request["Content-Length"] = file.size.to_s
        upload_request["X-Goog-Upload-Offset"] = "0"
        upload_request["X-Goog-Upload-Command"] = "upload, finalize"
        upload_request.body = file.binread

        upload_response = perform(upload_uri, upload_request)
        ensure_success!(upload_response)
        parse_json(upload_response)
      end

      def generate_text(model:, parts:, generation_config: nil, system_instruction: nil)
        uri = URI::HTTPS.build(host: API_HOST, path: "/v1beta/models/#{model}:generateContent")
        request = Net::HTTP::Post.new(uri)
        apply_json_headers(request)

        body = { contents: [ { parts: parts } ] }
        body[:generation_config] = generation_config if generation_config.present?
        body[:system_instruction] = { parts: [ { text: system_instruction } ] } if system_instruction.present?
        request.body = JSON.dump(body)

        response = perform(uri, request)
        ensure_success!(response)
        extract_text(parse_json(response))
      end

      protected

      def perform(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end
      end

      private

      attr_reader :api_key

      def apply_json_headers(request)
        request["Content-Type"] = "application/json"
        request["x-goog-api-key"] = api_key
      end

      def ensure_success!(response)
        return if response.code.to_i.between?(200, 299)

        raise GeminiError, "Gemini API request failed with HTTP #{response.code}: #{response.body}"
      end

      def parse_json(response)
        JSON.parse(response.body)
      rescue JSON::ParserError => error
        raise GeminiError, "Gemini API returned invalid JSON: #{error.message}"
      end

      def extract_text(payload)
        text = payload.fetch("candidates", []).flat_map do |candidate|
          candidate.dig("content", "parts").to_a.filter_map { |part| part["text"] }
        end.join("\n").strip

        raise GeminiError, "Gemini API response did not contain generated text." if text.empty?

        text
      end
    end
  end
end

require "base64"
require "net/http"
require "securerandom"
require "time"
require "uri"
require "nodl/integrity/der_encoding"
require "nodl/integrity/seal_result"

module Nodl
  module Integrity
    class TsaClient
      PROVIDER_RFC3161_FREETSA = "rfc3161_freetsa".freeze
      DEFAULT_URL = "https://freetsa.org/tsr".freeze
      PROOF_FORMAT_RFC3161 = "rfc3161-tsr".freeze
      GRANTED_STATUSES = [ 0, 1 ].freeze

      def self.from_env
        provider = ENV.fetch("INTEGRITY_TSA_PROVIDER", PROVIDER_RFC3161_FREETSA)
        url = ENV.fetch("INTEGRITY_TSA_URL") do
          Rails.env.test? ? "" : DEFAULT_URL
        end

        new(
          provider: provider,
          url: url,
          timeout_seconds: ENV.fetch("INTEGRITY_TSA_TIMEOUT_SECONDS", "8").to_f,
          retry_count: ENV.fetch("INTEGRITY_TSA_RETRY_COUNT", "1").to_i,
          retry_backoff_seconds: ENV.fetch("INTEGRITY_TSA_RETRY_BACKOFF_SECONDS", "0.5").to_f
        )
      end

      def initialize(provider:, url:, timeout_seconds:, retry_count:, retry_backoff_seconds:)
        @provider = provider.to_s.strip.presence || PROVIDER_RFC3161_FREETSA
        @url = url.to_s.strip
        @timeout_seconds = timeout_seconds
        @retry_count = [ retry_count, 0 ].max
        @retry_backoff_seconds = [ retry_backoff_seconds, 0 ].max
      end

      def seal_digest(digest:, hash_algorithm:)
        return pending_config("Unsupported TSA provider: #{provider}.") unless provider == PROVIDER_RFC3161_FREETSA
        return pending_config("TSA URL not configured.") if url.blank?

        request_body = DerEncoding.rfc3161_timestamp_request(
          digest: digest,
          hash_algorithm: hash_algorithm,
          nonce: SecureRandom.random_number(2**63)
        )
        response = post_with_retries(request_body)
        status, has_token = DerEncoding.rfc3161_response_status(response.body)

        unless GRANTED_STATUSES.include?(status) && has_token
          return failed("TSA returned PKIStatus #{status} without a timestamp token.")
        end

        TimestampProofResult.new(
          status: RecordingIntegrityRecord::STATUS_SEALED,
          provider: provider,
          authority: authority,
          proof_format: PROOF_FORMAT_RFC3161,
          proof_blob: Base64.strict_encode64(response.body),
          timestamp: timestamp_from(response),
          error: nil
        )
      rescue StandardError => error
        failed(error.message)
      end

      private

      attr_reader :provider, :url, :timeout_seconds, :retry_count, :retry_backoff_seconds

      def pending_config(error)
        TimestampProofResult.new(
          status: RecordingIntegrityRecord::STATUS_PENDING_CONFIG,
          provider: provider,
          authority: authority,
          proof_format: nil,
          proof_blob: nil,
          timestamp: nil,
          error: truncate_error(error)
        )
      end

      def failed(error)
        TimestampProofResult.new(
          status: RecordingIntegrityRecord::STATUS_FAILED,
          provider: provider,
          authority: authority,
          proof_format: nil,
          proof_blob: nil,
          timestamp: nil,
          error: truncate_error(error)
        )
      end

      def post_with_retries(body)
        attempts = retry_count + 1
        last_error = nil

        attempts.times do |attempt|
          return post(body)
        rescue StandardError => error
          last_error = error
          sleep(retry_backoff_seconds * (attempt + 1)) if attempt < attempts - 1 && retry_backoff_seconds.positive?
        end

        raise last_error
      end

      def post(body)
        uri = URI.parse(url)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/timestamp-query"
        request["Accept"] = "application/timestamp-reply"
        request.body = body

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: timeout_seconds, read_timeout: timeout_seconds) do |http|
          response = http.request(request)
          raise "TSA HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

          response
        end
      end

      def timestamp_from(response)
        Time.httpdate(response["Date"]).utc if response["Date"].present?
      rescue ArgumentError
        nil
      end

      def authority
        return if url.blank?

        URI.parse(url).host
      rescue URI::InvalidURIError
        nil
      end

      def truncate_error(error)
        error.to_s.truncate(500)
      end
    end
  end
end

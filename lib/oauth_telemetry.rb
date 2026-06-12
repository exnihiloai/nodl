# frozen_string_literal: true

# Emits operator-facing OAuth config telemetry without leaking secrets.
class OauthTelemetry
  CONFIG_MARKERS = %w[
    redirect_uri_mismatch
    invalid_client
    csrf_detected
  ].freeze

  class << self
    def config_failure?(error_class: nil, error_message: nil, error_type: nil)
      type = error_type.to_s
      return true if type == "csrf_detected"

      blob = [ error_class, error_message, type ].compact.join(" ")
      return true if CONFIG_MARKERS.any? { |marker| blob.include?(marker) }
      return true if error_class.to_s.end_with?("OAuth2::Error")

      false
    end

    def instrument_config_failure(reason:, request:, error: nil, error_type: nil, force: false)
      resolved_type = error_type || request.env["omniauth.error.type"]&.to_s
      error_class = error&.class&.name
      error_message = sanitized_message(error)

      return unless force || config_failure?(
        error_class: error_class,
        error_message: error_message,
        error_type: resolved_type
      )

      ActiveSupport::Notifications.instrument(
        "nodl.oauth.config_error",
        reason: reason.to_s,
        error_class: error_class,
        error_type: resolved_type.presence,
        error_message: error_message,
        ip: request.remote_ip
      )
    end

    private

    def sanitized_message(error)
      return if error.nil?

      error.message.to_s.squish.truncate(200)
    end
  end
end

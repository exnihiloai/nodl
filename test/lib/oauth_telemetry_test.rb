require "test_helper"

class OauthTelemetryTest < ActiveSupport::TestCase
  test "detects common oauth config failure markers" do
    assert OauthTelemetry.config_failure?(error_type: "csrf_detected")
    assert OauthTelemetry.config_failure?(error_message: "redirect_uri_mismatch")
    assert OauthTelemetry.config_failure?(error_message: "invalid_client")
    assert OauthTelemetry.config_failure?(error_class: "OAuth2::Error", error_message: "invalid_grant")
  end

  test "ignores non-config oauth failures" do
    assert_not OauthTelemetry.config_failure?(error_type: "access_denied")
    assert_not OauthTelemetry.config_failure?(error_class: "ActiveRecord::RecordInvalid")
  end

  test "instruments nodl.oauth.config_error for config failures" do
    request = ActionDispatch::TestRequest.create
    events = []
    ActiveSupport::Notifications.subscribe("nodl.oauth.config_error") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    error = StandardError.new("redirect_uri_mismatch")
    OauthTelemetry.instrument_config_failure(reason: "omniauth_failure", request:, error:)

    assert_equal 1, events.size
    assert_equal "omniauth_failure", events.first.payload[:reason]
    assert_includes events.first.payload[:error_message], "redirect_uri_mismatch"
  ensure
    ActiveSupport::Notifications.unsubscribe("nodl.oauth.config_error")
  end

  test "instruments forced config failures such as missing env" do
    request = ActionDispatch::TestRequest.create
    events = []
    ActiveSupport::Notifications.subscribe("nodl.oauth.config_error") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    OauthTelemetry.instrument_config_failure(reason: "not_configured", request:, force: true)

    assert_equal 1, events.size
    assert_equal "not_configured", events.first.payload[:reason]
  ensure
    ActiveSupport::Notifications.unsubscribe("nodl.oauth.config_error")
  end
end

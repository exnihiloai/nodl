require "test_helper"
require "stringio"

class OpenTelemetryTest < ActiveSupport::TestCase
  def with_env(overrides)
    previous = {}
    overrides.each do |key, value|
      previous[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end

    yield
  ensure
    overrides.each_key do |key|
      if previous[key].nil?
        ENV.delete(key)
      else
        ENV[key] = previous[key]
      end
    end
  end

  test "base endpoint enables telemetry and logs fallback endpoints" do
    config = Observability::OpenTelemetryConfig.new(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://signoz.internal:4318"
      },
      default_service_name: "nodl"
    )

    assert config.telemetry_enabled?
    assert config.logs_enabled?
    assert_equal "http://signoz.internal:4318/v1/traces", config.traces_endpoint
    assert_equal "http://signoz.internal:4318/v1/metrics", config.metrics_endpoint
    assert_equal "http://signoz.internal:4318/v1/logs", config.logs_endpoint
  end

  test "explicit logs endpoint overrides fallback" do
    config = Observability::OpenTelemetryConfig.new(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://signoz.internal:4318",
        "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT" => "http://logs-gateway.internal:4318/v1/logs"
      },
      default_service_name: "nodl"
    )

    assert_equal "http://logs-gateway.internal:4318/v1/logs", config.logs_endpoint
  end

  test "base endpoint can be provided as full traces path" do
    config = Observability::OpenTelemetryConfig.new(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "https://ingest.example.com/v1/traces"
      },
      default_service_name: "nodl"
    )

    assert_equal "https://ingest.example.com/v1/traces", config.traces_endpoint
    assert_equal "https://ingest.example.com/v1/metrics", config.metrics_endpoint
    assert_equal "https://ingest.example.com/v1/logs", config.logs_endpoint
  end

  test "ingest token is propagated into exporter headers" do
    config = Observability::OpenTelemetryConfig.new(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "https://signoz.example.com",
        "OTEL_INGEST_TOKEN" => "secret-token"
      },
      default_service_name: "nodl"
    )

    expected_headers = {
      "Authorization" => "Bearer secret-token",
      "signoz-ingestion-key" => "secret-token"
    }

    assert_equal expected_headers, config.token_headers
    assert_equal expected_headers, config.trace_exporter_options[:headers]
    assert_equal expected_headers, config.metrics_exporter_options[:headers]
    assert_equal expected_headers, config.logs_exporter_options[:headers]
  end

  test "service name is read from OTEL_SERVICE_NAME" do
    config = Observability::OpenTelemetryConfig.new(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "https://signoz.example.com",
        "OTEL_SERVICE_NAME" => "billing-api"
      },
      default_service_name: "nodl"
    )

    assert_equal "billing-api", config.service_name
  end

  test "invalid endpoint is ignored with warning" do
    config = Observability::OpenTelemetryConfig.new(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "not-a-valid-url"
      },
      default_service_name: "nodl"
    )

    refute config.enabled?
    assert_includes config.warnings.join(" "), "OTEL_EXPORTER_OTLP_ENDPOINT"
  end

  test "setup does not raise when env vars are missing" do
    log_output = StringIO.new
    logger = Logger.new(log_output)

    result = Observability::OpenTelemetrySetup.configure!(
      env: {},
      logger: logger,
      default_service_name: "nodl"
    )

    assert_equal false, result
    assert_includes log_output.string, "opentelemetry disabled"
  end

  test "setup does not raise when endpoint is invalid" do
    log_output = StringIO.new
    logger = Logger.new(log_output)

    result = Observability::OpenTelemetrySetup.configure!(
      env: {
        "OTEL_EXPORTER_OTLP_ENDPOINT" => ":::bad-url:::"
      },
      logger: logger,
      default_service_name: "nodl"
    )

    assert_equal false, result
    assert_includes log_output.string, "opentelemetry config warning"
  end
end

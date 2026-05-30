# frozen_string_literal: true

require "uri"

module Observability
  class OpenTelemetryConfig
    attr_reader :base_endpoint, :logs_endpoint, :metrics_endpoint, :service_name, :traces_endpoint, :warnings

    def initialize(env: ENV, default_service_name:)
      @env = env
      @warnings = []
      @base_endpoint = parse_endpoint("OTEL_EXPORTER_OTLP_ENDPOINT")
      @logs_endpoint = parse_endpoint("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT") || append_path(@base_endpoint, "v1/logs")
      @traces_endpoint = append_path(@base_endpoint, "v1/traces")
      @metrics_endpoint = append_path(@base_endpoint, "v1/metrics")
      @service_name = normalize_value(@env["OTEL_SERVICE_NAME"]) || default_service_name
    end

    def enabled?
      telemetry_enabled? || logs_enabled?
    end

    def telemetry_enabled?
      !@base_endpoint.nil?
    end

    def logs_enabled?
      !@logs_endpoint.nil?
    end

    def token_headers
      token = normalize_value(@env["OTEL_INGEST_TOKEN"])
      return {} if token.nil?

      {
        "Authorization" => "Bearer #{token}",
        "signoz-ingestion-key" => token
      }
    end

    def trace_exporter_options
      {
        endpoint: @traces_endpoint,
        headers: token_headers
      }
    end

    def logs_exporter_options
      {
        endpoint: @logs_endpoint,
        headers: token_headers
      }
    end

    def metrics_exporter_options
      {
        endpoint: @metrics_endpoint,
        headers: token_headers
      }
    end

    private

    def normalize_value(value)
      return nil if value.nil?

      normalized = value.strip
      normalized.empty? ? nil : normalized
    end

    def parse_endpoint(env_key)
      raw = normalize_value(@env[env_key])
      return nil if raw.nil?

      uri = URI.parse(raw)
      unless uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
        @warnings << "#{env_key} must be a valid http(s) URL. Ignoring #{raw.inspect}."
        return nil
      end

      uri.to_s
    rescue URI::InvalidURIError
      @warnings << "#{env_key} must be a valid http(s) URL. Ignoring #{raw.inspect}."
      nil
    end

    def append_path(endpoint, suffix)
      return nil if endpoint.nil?

      normalized_endpoint = normalize_otlp_base_endpoint(endpoint)
      URI.join("#{normalized_endpoint.chomp('/')}/", suffix).to_s
    rescue URI::InvalidURIError
      nil
    end

    def normalize_otlp_base_endpoint(endpoint)
      uri = URI.parse(endpoint)
      return endpoint unless uri.path

      uri.path = uri.path.sub(%r{/(v1/(traces|metrics|logs))/?$}, "/")
      uri.to_s
    rescue URI::InvalidURIError
      endpoint
    end
  end

  class OpenTelemetrySetup
    class << self
      def configure!(env: ENV, logger: Rails.logger, default_service_name: nil)
        default_service_name ||= inferred_default_service_name
        config = OpenTelemetryConfig.new(env: env, default_service_name: default_service_name)
        config.warnings.each { |warning| logger.warn("opentelemetry config warning: #{warning}") }

        unless config.enabled?
          logger.warn("opentelemetry disabled: set OTEL_EXPORTER_OTLP_ENDPOINT and/or OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
          return false
        end

        configure_sdk(config: config, env: env)
        install_request_metrics! if config.telemetry_enabled?
        logger.info("opentelemetry enabled: traces_metrics=#{config.telemetry_enabled?} logs=#{config.logs_enabled?} service_name=#{config.service_name}")
        true
      rescue LoadError => e
        logger.warn("opentelemetry setup skipped: missing dependency (#{e.message})")
        false
      rescue StandardError => e
        logger.warn("opentelemetry setup failed: #{e.class}: #{e.message}")
        false
      end

      private

      def configure_sdk(config:, env:)
        require "opentelemetry/sdk"
        require "opentelemetry-exporter-otlp"

        if config.telemetry_enabled?
          require "opentelemetry-metrics-sdk"
          require "opentelemetry-exporter-otlp-metrics"
          require "opentelemetry-instrumentation-rails"
        end

        if config.logs_enabled?
          require "opentelemetry-logs-sdk"
          require "opentelemetry-exporter-otlp-logs"
          require "opentelemetry-instrumentation-logger"
        end

        with_temporary_env(env, "OTEL_TRACES_EXPORTER" => (config.telemetry_enabled? ? nil : "none")) do
          OpenTelemetry::SDK.configure do |c|
            c.service_name = config.service_name unless config.service_name.to_s.empty?
            configure_traces_and_metrics(c: c, config: config) if config.telemetry_enabled?
            configure_logs(c: c, config: config) if config.logs_enabled?
          end
        end
      end

      def configure_traces_and_metrics(c:, config:)
        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
            OpenTelemetry::Exporter::OTLP::Exporter.new(**config.trace_exporter_options)
          )
        )

        c.add_metric_reader(
          OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(
            exporter: OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new(**config.metrics_exporter_options)
          )
        )

        c.use "OpenTelemetry::Instrumentation::Rails"
      end

      def configure_logs(c:, config:)
        c.add_log_record_processor(
          OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
            OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(**config.logs_exporter_options)
          )
        )
        c.use "OpenTelemetry::Instrumentation::Logger"
      end

      def install_request_metrics!
        return if @request_metrics_installed

        meter = OpenTelemetry.meter_provider.meter("nodl.rails")
        request_count = meter.create_counter(
          "rails.http.server.request.count",
          unit: "{request}",
          description: "Total Rails HTTP requests observed by process_action"
        )
        request_duration = meter.create_histogram(
          "rails.http.server.request.duration",
          unit: "ms",
          description: "Rails HTTP request duration emitted from process_action"
        )

        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |_name, started, finished, _id, payload|
          attributes = {
            "http.response.status_code" => payload[:status].to_i,
            "rails.controller" => payload[:controller].to_s,
            "rails.action" => payload[:action].to_s
          }

          request_count.add(1, attributes:)
          request_duration.record((finished - started) * 1000.0, attributes:)
        end

        @request_metrics_installed = true
      end

      def with_temporary_env(env, overrides)
        previous_values = {}
        overrides.each do |key, value|
          previous_values[key] = env[key]
          if value.nil?
            env.delete(key)
          else
            env[key] = value
          end
        end

        yield
      ensure
        overrides.each_key do |key|
          if previous_values[key].nil?
            env.delete(key)
          else
            env[key] = previous_values[key]
          end
        end
      end

      def inferred_default_service_name
        Rails.application.class.module_parent_name.underscore.tr("/", "-")
      end
    end
  end
end

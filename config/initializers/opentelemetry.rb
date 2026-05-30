# frozen_string_literal: true

require Rails.root.join("lib/observability/open_telemetry")

Observability::OpenTelemetrySetup.configure!

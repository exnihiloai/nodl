require "test_helper"

# Regression guard for browser ↔ app encryption in transit. These are production
# settings (the test environment runs without TLS), so we assert the production
# environment file keeps HTTPS enforced and health probes reachable. A static
# check, deliberately, so accidental removal of these lines fails the suite.
class TransportSecurityTest < ActiveSupport::TestCase
  PRODUCTION_ENV = Rails.root.join("config", "environments", "production.rb").read

  test "production forces SSL and assumes a TLS-terminating proxy" do
    assert_match(/^\s*config\.force_ssl\s*=\s*true/, PRODUCTION_ENV,
      "production must force all traffic over SSL (HSTS + secure cookies)")
    assert_match(/^\s*config\.assume_ssl\s*=\s*true/, PRODUCTION_ENV,
      "production must assume SSL behind the terminating proxy")
  end

  test "health checks stay reachable without breaking user-facing TLS" do
    assert_match(/ssl_options.*redirect.*exclude/m, PRODUCTION_ENV,
      "production must exclude health endpoints from the SSL redirect")
    %w[/up /healthz /readyz].each do |path|
      assert_includes PRODUCTION_ENV, "\"#{path}\"",
        "health endpoint #{path} must remain reachable for operations"
    end
  end
end

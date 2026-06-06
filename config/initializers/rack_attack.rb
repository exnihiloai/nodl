# Rack::Attack — edge defense against scanner bots and abuse.
#
# Counters live in Rails.cache (solid_cache in production, memory in development),
# the same store the login throttle in SessionsController already relies on. The
# middleware is inserted automatically by Rack::Attack's railtie.
#
# Disabled in test so the suite stays deterministic (the test cache is a
# :null_store, which would no-op the counters anyway).
#
# Note on client IPs behind a proxy: in production the app runs behind
# kamal-proxy/Thruster, which set X-Forwarded-For. `req.ip` honors that via
# ActionDispatch's trusted-proxy handling, so throttles key on the real client.
Rack::Attack.enabled = !Rails.env.test?

class Rack::Attack
  # Scanner targets this app never serves — block fast with a 403 instead of
  # letting them walk the 404 surface (fail2ban-lite).
  BLOCKED_PATH_PATTERNS = [
    %r{\A/\.env},
    %r{\A/\.git},
    %r{\A/\.aws},
    %r{\A/wp-(login|admin|content|includes)},
    %r{/xmlrpc\.php\z},
    %r{/phpmyadmin}i,
    %r{/vendor/phpunit}i
  ].freeze

  ### Safelists ###

  # Never throttle health checks (monitoring / load balancers).
  safelist("allow health checks") do |req|
    %w[/up /healthz /readyz].include?(req.path)
  end

  ### Throttles ###

  # General per-IP ceiling: absorbs aggressive scanning/scraping without
  # affecting normal interactive use (1 req/sec sustained). Assets and the
  # Action Cable socket are excluded.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/cable")
  end

  # Account creation is the most abusable open endpoint — each signup creates a
  # User + Workspace + default transformer. Cap new registrations per IP.
  throttle("registrations/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/register"
  end

  # Defense in depth on login (SessionsController already throttles per
  # email+IP; this adds a coarser per-IP cap against distributed guessing).
  throttle("logins/ip", limit: 15, period: 20.minutes) do |req|
    req.ip if req.post? && req.path == "/login"
  end

  ### Blocklist ###

  blocklist("block junk probes") do |req|
    BLOCKED_PATH_PATTERNS.any? { |pattern| req.path.match?(pattern) }
  end

  ### Responses ###

  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "content-type" => "text/plain", "retry-after" => retry_after.to_s },
      [ "Too many requests. Please retry later.\n" ]
    ]
  end

  self.blocklisted_responder = lambda do |_req|
    [ 403, { "content-type" => "text/plain" }, [ "Forbidden\n" ] ]
  end
end

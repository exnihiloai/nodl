# User Story: Telemetry

As app maintainer, taking care of the availability and functionality of the app, I want to receive telemetry information that helps me understand usage, sign ins, and user activity, so that I can spot problems early, see whether the product is actually being used, and respond before users have to tell me something is broken.

## Acceptance Criteria

- I receive a timely alert when a new account is created (email and timestamp only — no passwords or secrets).
- I receive a timely alert when someone signs in successfully (who and when; no session tokens).
- I receive a summary or alert for meaningful product usage, at minimum: a new recording session started and a document successfully generated.
- I receive a timely alert for landing-page visits so I can tell whether marketing traffic is arriving (rate-limited or batched so a traffic spike does not spam me).
- Alerts are optional and configured through environment variables; when not configured, the app behaves exactly as today and user flows are never blocked by a failed notification.
- Notifications must not leak sensitive content (transcripts, audio, document body, API keys).
- Development and automated test runs do not send real maintainer alerts by default.
- Telemetry complements the existing OpenTelemetry export (SigNoz): alerts are for immediate awareness; OTEL remains the place for deeper investigation, trends, and availability history.
- A short setup note exists for maintainers (which env vars to set, how to verify a test alert, how to turn alerts off).

## Out of Scope

- End-user analytics dashboards or in-app usage charts.
- Full product analytics (funnels, cohorts, A/B tests).
- Replacing SigNoz, health checks, or structured application logging.
- Storing every page view in the application database.

## Additional Information

- Preferred delivery channel: Telegram
- Landing visits: one alert per visit
- Failed sign-ins are logged to detect abuse

# Security Hardener (Rails)

Apply security fixes to this Rails app based on the latest audit findings. Keep the posture strong within reasonable limits (good practices, avoid extreme/fragile hardening).

## Inputs

- `doc/security-audit-report.md` (preferred): list of issues with severity + locations.
- Scanner outputs (optional): `tmp/security-audit/*.txt` from the auditor skill.

## Hardening Workflow

1. Triage and plan
   - Sort by severity: CRITICAL -> HIGH -> MEDIUM -> LOW.
   - Confirm exploitability and blast radius.
   - Identify which changes touch sensitive areas: auth, sessions, tenancy, billing.
2. Implement fixes incrementally
   - Make the smallest change that eliminates the root cause.
   - Add/adjust tests for security-relevant behavior where feasible.
   - Update docs if behavior/config changes.
3. Verify after each batch
   - `make lint`
   - `make test`
   - Re-run scanners:
     - `bin/brakeman --no-pager`
     - `bin/bundler-audit`
     - `bin/importmap audit`

## Guard Rails (stop and ask)

Stop and ask the user before making changes that:

- alter authentication flows or session/cookie settings
- change tenant resolution / workspace scoping behavior
- modify billing/payment behavior
- require production secrets / service credentials

## Typical Fix Areas (Rails)

- Strong params and model validations
- Authorization checks (especially multi-tenant boundaries / IDOR)
- Safer redirects (`redirect_to` allowlists)
- XSS hardening (avoid `html_safe`, ensure escaping)
- Header hardening (CSP, HSTS in production, secure cookies)
- Parameter filtering for PII
- Dependency upgrades for CVEs

## Done Criteria

- All CRITICAL/HIGH findings addressed or explicitly accepted (with documented rationale).
- `make lint` and `make test` pass.
- Scanners are clean or improved; remaining warnings are triaged and documented.

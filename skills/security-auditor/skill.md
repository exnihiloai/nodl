# Security Auditor (Rails)

Perform an agentic cyber security audit of this Rails repository and produce a prioritized, actionable report.

## Goals

- Identify vulnerabilities and risky patterns in code and configuration.
- Run scanner tools for third-party dependency hygiene.
- Produce a clear remediation plan within "reasonable limits" (good practices, not extreme hardening).

## Entry Point

Run the scanners (optional but recommended first):

```bash
skills/security-auditor/scripts/security_audit.sh
```

The script prefers running scanners inside the Docker Compose `web` service when available, and falls back to local execution otherwise.

## Audit Workflow (agentic)

1. Run scanners and collect outputs:
   - `bin/brakeman --no-pager`
   - `bin/bundler-audit`
   - `bin/importmap audit`
2. Review application security posture:
   - AuthN/AuthZ: session handling, password storage, account lifecycle, admin access controls.
   - Multi-tenancy: ensure workspace scoping on reads/writes; check for IDOR across tenants.
   - CSRF/CSP/headers: confirm defaults and overrides are sensible.
   - Input validation: strong params, model validations, file upload safety (if present).
   - Open redirect / SSRF: any redirect_to params, URL fetches, webhooks.
   - XSS: unsafe `raw`, `html_safe`, inline scripts, unescaped user content.
   - Logging/PII: avoid patient data in logs, filter parameters, structured logging.
   - Secrets: ensure no secrets in repo; env vars and credentials usage is safe.
   - Docker/deploy: least privilege, image pinning, exposed ports, debug endpoints.
3. Confirm "reasonable" mitigations exist for likely patient-data use:
   - secure cookies, strict session settings
   - encryption at rest features (Rails credentials / ActiveRecord encryption if applicable)
   - audit trail for admin actions (if implemented)
4. Write the report at `doc/security-audit-report.md`.

## Required Report Format

Write `doc/security-audit-report.md` using this structure:

```markdown
# Security Audit Report

Generated: <YYYY-MM-DD>
Scope: Nodl Rails app (code + config + dependency scans)

## Summary

| Severity | Count |
|---|---:|
| CRITICAL | N |
| HIGH | N |
| MEDIUM | N |
| LOW | N |

## Findings

### S-001 · <TITLE> · Severity: <CRITICAL|HIGH|MEDIUM|LOW> · Confidence: <0-100>%

**Where:** `<file>:<line>`
**Issue:** one paragraph
**Impact:** one paragraph
**Evidence:** short snippet or command output reference
**Fix:** concrete steps (and which tests/scanners to re-run)

---

## Scanner Outputs

- Brakeman: include command + summary
- bundler-audit: include command + summary
- importmap audit: include command + summary

## Recommended Next Steps (ordered)

1. Fix CRITICAL
2. Fix HIGH
3. Fix MEDIUM
4. Fix LOW
```

## Rules

- Do not hallucinate. If you cannot verify, mark as "Unable to verify" with low confidence.
- Stop and ask for clarification before recommending risky breaking changes to auth, tenancy, billing, or session/cookie behavior.
- Prefer Rails ecosystem best practices and official guidance over custom security frameworks.

# SEO Shared Preamble

Every SEO skill reads this before doing anything else. It locates scripts and
verifies Google Search Console credentials — no MCP server required.

## Step 1 — Credentials (GSC API)

Search Console data uses the **Google Search Console API** directly.

Set `GSC_API_KEY` in `.env` or `private/.env` (see repo `.env.example`):

| Value | Meaning |
| --- | --- |
| Path to a `.json` file | Google **service account** key (add the service account email as a user in Search Console) |
| `ya29.…` token string | Short-lived OAuth access token |

Optional fallback: `GOOGLE_APPLICATION_CREDENTIALS` pointing at service account JSON.

Install Python deps once (service account auth):

```bash
pip install -r skills/seo/seo-analysis/scripts/requirements.txt
```

Verify credentials:

```bash
python3 "$SKILL_SCRIPTS/preflight.py"
```

Expected: `OK: GSC ready via environment credentials.`

If `GSC_API_KEY` is not set, scripts fall back to `gcloud auth application-default login` (legacy).

> **Reference**: [../seo-analysis/references/gsc_setup.md](../seo-analysis/references/gsc_setup.md)

## Step 2 — Locate skill scripts

Scripts live in this repository under `skills/seo/seo-analysis/scripts/`:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export NODL_ROOT="$REPO_ROOT"
SKILL_SCRIPTS="$REPO_ROOT/skills/seo/seo-analysis/scripts"
```

Use `$SKILL_SCRIPTS` for all subsequent script calls.

## Step 3 — SEO data directory

Cache audit logs, personas, and business context under:

```bash
SEO_DATA_DIR="${NODL_SEO_DATA_DIR:-$HOME/.nodl/seo}"
mkdir -p "$SEO_DATA_DIR"
```

## Step 4 — Proceed

Scripts are at `$SKILL_SCRIPTS`, GSC auth is configured. Hand control back to the invoking skill.

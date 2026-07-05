# Google Search Console API Setup (nodl)

SEO skills call `https://searchconsole.googleapis.com` directly. No MCP server.

## 1. Enable the API

In [Google Cloud Console](https://console.cloud.google.com/apis/library/searchconsole.googleapis.com), enable **Google Search Console API** for your project.

## 2. Create credentials

**Recommended — service account**

1. IAM & Admin → Service Accounts → Create
2. Create a JSON key and download it
3. In [Search Console](https://search.google.com/search-console) → Settings → Users and permissions, add the service account email (at least **Restricted** access)

**Alternative — OAuth access token**

Use [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/) with scope  
`https://www.googleapis.com/auth/webmasters`  
Copy the access token (expires in ~1 hour — service account is better for automation).

## 3. Configure nodl

Add to `.env` or `private/.env`:

```bash
# Path to service account JSON, or a short-lived OAuth access token
GSC_API_KEY=/absolute/path/to/service-account.json
```

Install script dependencies:

```bash
pip install -r skills/seo/seo-analysis/scripts/requirements.txt
```

## 4. Verify

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
python3 "$REPO_ROOT/skills/seo/seo-analysis/scripts/list_gsc_sites.py"
```

You should see your Search Console properties.

## Troubleshooting

**403 / API not enabled** — enable Search Console API in the GCP project tied to your credentials.

**No properties listed** — wrong Google account; service account must be added in GSC user settings.

**403 quota project** — set `project_id` in the service account JSON (automatic) or use a token from the correct GCP project.

**URL Inspection fails** — token must include `webmasters` scope (not readonly only). Service accounts configured via `_gsc_auth.py` request both scopes.

## Legacy: gcloud CLI

If `GSC_API_KEY` is unset, scripts fall back to Application Default Credentials:

```bash
gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/webmasters,https://www.googleapis.com/auth/webmasters.readonly
```

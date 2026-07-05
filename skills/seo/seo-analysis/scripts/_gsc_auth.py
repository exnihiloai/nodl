"""Google Search Console API authentication for nodl SEO skills.

Credentials (first match wins):
  1. GSC_API_KEY — OAuth access token, or path to a service account JSON file
  2. GOOGLE_APPLICATION_CREDENTIALS — path to service account JSON
  3. gcloud application-default credentials (legacy fallback)

Set GSC_API_KEY in .env or private/.env (see .env.example).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

from _gcloud import gcloud_run

GSC_SCOPES = (
    "https://www.googleapis.com/auth/webmasters",
    "https://www.googleapis.com/auth/webmasters.readonly",
)

_ENV_LOADED = False


def load_env_files():
    """Load .env-style files into os.environ without overwriting existing vars."""
    global _ENV_LOADED
    if _ENV_LOADED:
        return

    repo_root = os.environ.get("NODL_ROOT", "").strip()
    if not repo_root:
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))

    default_key = os.path.join(repo_root, "private", "google-search-console-api.json")
    if os.path.isfile(default_key):
        os.environ.setdefault("GSC_API_KEY", default_key)

    candidates = [
        ".env",
        ".env.local",
        os.path.join(repo_root, "private", ".env"),
        os.path.join(repo_root, ".env"),
        os.path.expanduser("~/.nodl/seo/.env"),
    ]
    repo_root = os.environ.get("NODL_ROOT")
    if repo_root:
        candidates.insert(0, os.path.join(repo_root, ".env"))
        candidates.insert(1, os.path.join(repo_root, "private", ".env"))

    for path in candidates:
        if not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip().strip("'\"")
                    os.environ.setdefault(key, value)
        except OSError:
            continue

    _ENV_LOADED = True


def _gsc_api_key_value():
    load_env_files()
    for name in ("GSC_API_KEY", "GOOGLE_SEARCH_CONSOLE_API_KEY"):
        value = os.environ.get(name, "").strip()
        if value:
            return value
    creds_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    return creds_path if creds_path else ""


def _looks_like_access_token(value: str) -> bool:
    if value.startswith("ya29."):
        return True
    return len(value) > 80 and " " not in value and not value.endswith(".json")


def _service_account_info(value: str) -> dict | None:
    if value.startswith("{"):
        try:
            data = json.loads(value)
        except json.JSONDecodeError:
            return None
        return data if isinstance(data, dict) and data.get("type") == "service_account" else None

    path = os.path.expanduser(value)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) and data.get("type") == "service_account" else None


def _token_from_service_account(info: dict) -> str:
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account
    except ImportError:
        print(
            "ERROR: google-auth is required for service account credentials.",
            file=sys.stderr,
        )
        print(
            "  pip install -r skills/seo/seo-analysis/scripts/requirements.txt",
            file=sys.stderr,
        )
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_info(
        info,
        scopes=list(GSC_SCOPES),
    )
    credentials.refresh(Request())
    token = credentials.token
    if not token:
        print("ERROR: Service account returned an empty access token.", file=sys.stderr)
        sys.exit(1)
    return token


def _token_from_gcloud() -> str:
    try:
        result = gcloud_run(
            ["gcloud", "auth", "application-default", "print-access-token"],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except FileNotFoundError:
        print("ERROR: No GSC credentials found.", file=sys.stderr)
        print("  Set GSC_API_KEY in .env or private/.env (see .env.example).", file=sys.stderr)
        print("  Or install gcloud and run: gcloud auth application-default login", file=sys.stderr)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print("ERROR: gcloud timed out after 15s.", file=sys.stderr)
        sys.exit(1)

    if result.returncode != 0:
        print("ERROR: Not authenticated for Search Console.", file=sys.stderr)
        print("  Set GSC_API_KEY in .env or private/.env", file=sys.stderr)
        sys.exit(1)

    token = result.stdout.strip()
    if not token:
        print("ERROR: gcloud returned an empty token.", file=sys.stderr)
        sys.exit(1)
    return token


def get_access_token() -> str:
    """Return a Bearer token for searchconsole.googleapis.com."""
    key_value = _gsc_api_key_value()
    if key_value:
        service_account = _service_account_info(key_value)
        if service_account:
            return _token_from_service_account(service_account)
        if _looks_like_access_token(key_value):
            return key_value
        print(
            "ERROR: GSC_API_KEY must be an OAuth access token or a service account JSON path.",
            file=sys.stderr,
        )
        sys.exit(1)

    return _token_from_gcloud()


def get_quota_project() -> str | None:
    """Return GCP project id for x-goog-user-project header, if needed."""
    load_env_files()
    explicit = os.environ.get("GSC_QUOTA_PROJECT", "").strip()
    if explicit:
        return explicit

    key_value = _gsc_api_key_value()
    if key_value and _service_account_info(key_value):
        # Service accounts authorized in Search Console usually work without this
        # header. Sending project_id from the key file often triggers 403 when the
        # SA lacks serviceusage.serviceUsageConsumer on that GCP project.
        return None

    adc_dir = os.environ.get("CLOUDSDK_CONFIG") or os.path.join(
        os.path.expanduser("~"),
        ".config",
        "gcloud",
    )
    adc_path = os.path.join(adc_dir, "application_default_credentials.json")
    try:
        with open(adc_path, encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return data.get("quota_project_id") or None
    except (OSError, ValueError, json.JSONDecodeError):
        pass
    return None


def gsc_auth_headers() -> dict[str, str]:
    """Authorization (+ optional quota project) headers for GSC REST calls."""
    headers = {"Authorization": f"Bearer {get_access_token()}"}
    quota_project = get_quota_project()
    if quota_project:
        headers["x-goog-user-project"] = quota_project
    return headers


def credentials_configured() -> bool:
    """True when env-based credentials are present (before validating them)."""
    load_env_files()
    return bool(_gsc_api_key_value())

#!/usr/bin/env python3
"""List all Google Search Console properties for the authenticated account."""

import json
import os
import sys
import tempfile
import urllib.request
import urllib.error

from _gsc_auth import get_access_token, get_quota_project
from _uid import portable_uid, secure_write_json


def list_sites(token):
    url = "https://searchconsole.googleapis.com/webmasters/v3/sites"
    headers = {"Authorization": f"Bearer {token}"}
    quota_project = get_quota_project()
    if quota_project:
        headers["x-goog-user-project"] = quota_project
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data.get("siteEntry", [])
    except urllib.error.HTTPError as e:
        err_body = e.read().decode() if e.fp else "(no body)"
        print(f"ERROR {e.code}: {err_body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR: Network failure: {e.reason}", file=sys.stderr)
        sys.exit(1)


def main():
    token = get_access_token()
    sites = list_sites(token)

    if not sites:
        print("No Search Console properties found for this account.")
        print("Check GSC_API_KEY and that the account has Search Console access.")
        sys.exit(0)

    print(f"Found {len(sites)} Search Console properties:\n")
    for i, site in enumerate(sites, 1):
        ptype = "Domain" if site["siteUrl"].startswith("sc-domain:") else "URL-prefix"
        level = site.get("permissionLevel", "unknown")
        print(f"  {i}. {site['siteUrl']}")
        print(f"     Type: {ptype} | Permission: {level}")

    sites_path = os.path.join(tempfile.gettempdir(), f"gsc_sites_{portable_uid()}.json")
    secure_write_json(sites_path, sites)
    print(f"\n(Full list saved to {sites_path})")


if __name__ == "__main__":
    main()

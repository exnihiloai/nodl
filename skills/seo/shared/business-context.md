# SEO Business Context

Business context captures stable facts about a business that don't change run-to-run — name, goals, competitors, audience, brand terms. Caching these avoids repeating the same questions on every audit.

Assumes `preamble.md` has already run (`$SKILL_SCRIPTS` is set). Requires `$TARGET_URL` from Step 0.

## Cache location

```bash
SEO_DATA_DIR="${NODL_SEO_DATA_DIR:-$HOME/.nodl/seo}"
DOMAIN=$(python3 -c "import sys; from urllib.parse import urlparse; print(urlparse(sys.argv[1]).netloc.lstrip('www.'))" "$TARGET_URL")
BC_FILE="$SEO_DATA_DIR/business-context/$DOMAIN.json"
```

## Loading

```bash
mkdir -p "$SEO_DATA_DIR/business-context"
if [ -f "$BC_FILE" ]; then
  AGE_DAYS=$(python3 -c "
import json, sys
from datetime import datetime, timezone
data = json.load(open(sys.argv[1]))
gen = datetime.fromisoformat(data.get('generated_at', '1970-01-01T00:00:00+00:00'))
print((datetime.now(timezone.utc) - gen.astimezone(timezone.utc)).days)
" "$BC_FILE")
  cat "$BC_FILE"
  [ "$AGE_DAYS" -lt 90 ] && echo "CACHE_STATUS=fresh_loaded" || echo "CACHE_STATUS=stale"
else
  echo "CACHE_STATUS=not_found"
fi
```

**`CACHE_STATUS=fresh_loaded`**: extract `brand_terms` → `$BC_BRAND_TERMS`. Skip the brand-terms question in Phase 2.

**`CACHE_STATUS=stale`**: use as pre-fill; refresh after Phase 3.

**`CACHE_STATUS=not_found`**: proceed to Generation after Phase 3.

## Generation (after Phase 3)

Infer from GSC + homepage: brand terms, top query clusters, geographies, business type signals.

Ask at most three short questions (user may press Enter to skip — infer from data):

1. Business name and what you do (one sentence)
2. Primary website goal (lead gen, SaaS, ecommerce, local, content)
3. Main competitors (optional)

Save to `$BC_FILE` as JSON with `generated_at`, `target_url`, `domain`, `brand_terms`, `business_summary`, `primary_goal`, `competitors`, `notes`.

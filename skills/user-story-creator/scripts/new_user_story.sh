#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <repo-root> <story-title> [YYYY-MM-DD]" >&2
  exit 1
fi

repo_root="$1"
story_title="$2"
story_date="${3:-$(date +%F)}"

if [[ ! "$story_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: date must be in YYYY-MM-DD format." >&2
  exit 1
fi

if [[ ! -d "$repo_root/doc/user-stories" ]]; then
  echo "Error: '$repo_root/doc/user-stories' does not exist." >&2
  exit 1
fi

slug="$(printf '%s' "$story_title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
if [[ -z "$slug" ]]; then
  echo "Error: story title produced an empty slug. Use letters/numbers in title." >&2
  exit 1
fi

output_file="$repo_root/doc/user-stories/$story_date $slug.md"
if [[ -e "$output_file" ]]; then
  echo "Error: file already exists: $output_file" >&2
  exit 1
fi

{
  echo "## User Story: $story_title"
  cat <<'TEMPLATE'

**As a** <type of user>,
**I want to** <goal/action>,
**so that** <business value>.

### Background
- Explain the current problem and why this change matters.
- Include key constraints (permissions, tenancy, legal, performance).

### In Scope
- <scope item 1>
- <scope item 2>
- <scope item 3>

### Out of Scope
- <non-goal 1>
- <non-goal 2>

### Acceptance Criteria
- AC-01: <observable behavior>
- AC-02: <observable behavior>
- AC-03: <observable behavior>
- AC-04: <observable behavior>

### Technical Notes (Rails)
- Prefer RESTful routes, thin controllers, model validations, and ERB partial reuse.
- Keep tenancy boundaries explicit (workspace/user scoping).
- Keep interactions server-rendered; use Turbo/Stimulus only where needed.

### Testing
- Integration tests: request/validation/authorization coverage.
- System tests: key happy path and key failure path.
- Include regression checks for permission boundaries.

### Definition of Done
- All acceptance criteria implemented.
- Tests added/updated and passing with `make test`.
- Documentation updated where relevant.
- No known regressions.
TEMPLATE
} > "$output_file"

echo "Created user story: $output_file"

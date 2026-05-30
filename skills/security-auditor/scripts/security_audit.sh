#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Error: $1" >&2
  exit 1
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Not inside a git repository."
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

mkdir -p tmp/security-audit

docker_compose_available() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

compose_has_web_service() {
  docker compose config --services 2>/dev/null | grep -qx "web"
}

compose_web_running() {
  docker compose ps --status running --services 2>/dev/null | grep -qx "web"
}

run_scanner() {
  local label="$1"
  local command="$2"
  local output_path="$3"

  echo "Running $label..."

  if docker_compose_available && compose_has_web_service; then
    if compose_web_running; then
      docker compose exec -T web bash -lc "$command" >"$output_path" 2>&1 || true
    else
      docker compose run --rm -T web bash -lc "$command" >"$output_path" 2>&1 || true
    fi
  else
    bash -lc "$command" >"$output_path" 2>&1 || true
  fi
}

if docker_compose_available && compose_has_web_service; then
  if compose_web_running; then
    echo "Scanner runtime: docker compose exec -T web"
  else
    echo "Scanner runtime: docker compose run --rm -T web"
  fi
else
  echo "Scanner runtime: local shell"
fi

run_scanner "Brakeman" "bin/brakeman --no-pager" "tmp/security-audit/brakeman.txt"
run_scanner "bundler-audit" "bin/bundler-audit" "tmp/security-audit/bundler-audit.txt"
run_scanner "importmap audit" "bin/importmap audit" "tmp/security-audit/importmap-audit.txt"

echo "Scanner outputs written to tmp/security-audit/"
echo "  - tmp/security-audit/brakeman.txt"
echo "  - tmp/security-audit/bundler-audit.txt"
echo "  - tmp/security-audit/importmap-audit.txt"

echo
echo "Note: Non-zero findings do not fail this script. Use outputs to build doc/security-audit-report.md."

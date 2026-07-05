#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT_DIR/scripts/skills_generator.rb"
COMMAND="${1:-generate}"

if [[ ! -x "$GENERATOR" ]]; then
  echo "Missing generator: $GENERATOR" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

render_tmp() {
  ruby "$GENERATOR" "$tmp_dir"
}

extract_agent_instructions() {
  local destination="$1"

  awk '
    BEGIN { in_block = 0; found_begin = 0; found_end = 0 }
    $0 == "<!-- BEGIN AGENT INSTRUCTIONS -->" { in_block = 1; found_begin = 1; next }
    $0 == "<!-- END AGENT INSTRUCTIONS -->" { in_block = 0; found_end = 1; exit }
    in_block { print }
    END { if (!found_begin || !found_end) exit 2 }
  ' "$ROOT_DIR/README.md" > "$destination" || {
    echo "Failed to extract AGENT INSTRUCTIONS block from README.md" >&2
    return 1
  }
}

sync_agent_instruction_files() {
  local extracted="$tmp_dir/agent_instructions.md"
  extract_agent_instructions "$extracted"
  cp "$extracted" "$ROOT_DIR/AGENTS.md"
  cp "$extracted" "$ROOT_DIR/CLAUDE.md"
}

case "$COMMAND" in
  generate)
    render_tmp
    rm -rf "$ROOT_DIR/.claude/agents" "$ROOT_DIR/.claude/skills" "$ROOT_DIR/.codex/skills" "$ROOT_DIR/SKILL.md"
    mkdir -p "$ROOT_DIR/.claude" "$ROOT_DIR/.codex"
    cp -R "$tmp_dir/.claude/agents" "$ROOT_DIR/.claude/agents"
    cp -R "$tmp_dir/.claude/skills" "$ROOT_DIR/.claude/skills"
    cp -R "$tmp_dir/.codex/skills" "$ROOT_DIR/.codex/skills"
    cp "$tmp_dir/SKILL.md" "$ROOT_DIR/SKILL.md"
    sync_agent_instruction_files
    echo "Generated skill outputs in .claude/skills, .claude/agents, .codex/skills, and SKILL.md"
    ;;
  check)
    render_tmp
    if git -C "$ROOT_DIR" ls-files .claude/agents .claude/skills .codex/skills SKILL.md | grep -q .; then
      echo "Generated skill outputs are tracked by git. Remove them from index and keep them ignored." >&2
      exit 1
    fi

    if find "$tmp_dir/.claude/agents" "$tmp_dir/.claude/skills" "$tmp_dir/.codex/skills" -type l | grep -q .; then
      echo "Symlinks detected in generated outputs, which is not allowed." >&2
      exit 1
    fi

    missing_claude_skills=0
    while IFS= read -r skill_md; do
      [[ -f "$skill_md" ]] || continue
      if ! head -n 1 "$skill_md" | grep -q '^---$'; then
        echo "Invalid Claude skill (missing frontmatter): $skill_md" >&2
        missing_claude_skills=1
      fi
    done < <(find "$tmp_dir/.claude/skills" -name SKILL.md | sort)
    if [[ "$missing_claude_skills" -ne 0 ]]; then
      exit 1
    fi

    claude_skill_count="$(find "$tmp_dir/.claude/skills" -mindepth 2 -name SKILL.md | wc -l | tr -d ' ')"
    if [[ "$claude_skill_count" -eq 0 ]]; then
      echo "No Claude Code skills generated under .claude/skills/" >&2
      exit 1
    fi

    expected_agent_instructions="$tmp_dir/agent_instructions.md"
    extract_agent_instructions "$expected_agent_instructions"

    if [[ ! -f "$ROOT_DIR/AGENTS.md" ]] || ! cmp -s "$expected_agent_instructions" "$ROOT_DIR/AGENTS.md"; then
      echo "AGENTS.md is not in sync with README.md AGENT INSTRUCTIONS block. Run: make skills" >&2
      exit 1
    fi

    if [[ ! -f "$ROOT_DIR/CLAUDE.md" ]] || ! cmp -s "$expected_agent_instructions" "$ROOT_DIR/CLAUDE.md"; then
      echo "CLAUDE.md is not in sync with README.md AGENT INSTRUCTIONS block. Run: make skills" >&2
      exit 1
    fi

    echo "Skill sources are valid and generated outputs are not tracked."
    ;;
  clean)
    rm -rf "$ROOT_DIR/.claude/agents" "$ROOT_DIR/.claude/skills" "$ROOT_DIR/.codex/skills" "$ROOT_DIR/SKILL.md"
    mkdir -p "$ROOT_DIR/.claude/agents" "$ROOT_DIR/.claude/skills" "$ROOT_DIR/.codex/skills"
    echo "Cleaned generated skill outputs"
    ;;
  *)
    echo "Usage: $0 [generate|check|clean]" >&2
    exit 1
    ;;
esac

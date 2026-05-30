#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/skills"
ID="${1:-}"
NAME="${2:-}"

if [[ -z "$ID" || -z "$NAME" ]]; then
  echo "Usage: $0 <skill-id> <skill-name>" >&2
  exit 1
fi

if [[ ! "$ID" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "Invalid skill id '$ID'. Use lowercase letters, numbers, hyphens, and underscores." >&2
  exit 1
fi

TARGET_DIR="$SKILLS_DIR/$ID"
if [[ -e "$TARGET_DIR" ]]; then
  echo "Skill already exists: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR/scripts"

cat > "$TARGET_DIR/manifest.yml" <<MANIFEST
id: $ID
name: "$NAME"
version: "0.1.0"

entrypoints: []

instructions:
  summary: "Describe what this skill does in 1-2 lines."
  steps:
    - "Replace this with the first concrete step."
    - "Replace this with the second concrete step."

inputs: []
outputs: []

compat:
  claude_agent: true
  codex_skill: true
MANIFEST

cat > "$TARGET_DIR/skill.md" <<'SKILL'
# Skill Purpose

Describe the purpose of this skill and the outcome it should achieve.

## Prerequisites

List dependencies, tools, environment variables, and required paths.

## Usage

Example 1:
- User asks: "..."
- Expected workflow: "..."

Example 2:
- User asks: "..."
- Expected workflow: "..."

## Edge Cases

Document common failure modes and how to handle them.

## Output and Artifacts

List which files, folders, or other artifacts this skill reads/writes.
SKILL

echo "Created canonical skill scaffold at: $TARGET_DIR"
echo "Next steps:"
echo "  1) Fill in manifest.yml and skill.md"
echo "  2) Add scripts to $TARGET_DIR/scripts if needed"
echo "  3) Run make skills"

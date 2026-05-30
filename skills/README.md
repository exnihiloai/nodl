# Skills (Single Source of Truth)

This repository uses a unified skill source format.

## Canonical Source

Edit skills only under:

- `skills/<skill-id>/manifest.yml`
- `skills/<skill-id>/skill.md`
- `skills/<skill-id>/scripts/*` (optional)

Never edit generated outputs directly.

## Generated Outputs

`make skills` generates native target structures:

- Claude Code: `.claude/agents/<skill-id>.md`
- Codex: `.codex/skills/<skill-id>/agents/openai.yaml`
- Codex: `.codex/skills/<skill-id>/SKILL.md`
- Codex scripts: `.codex/skills/<skill-id>/scripts/*` (if present)
- Repo index: `SKILL.md`

Generated files include `GENERATED FILE - DO NOT EDIT` headers.
Generated files are local build artifacts and are intentionally git-ignored.

## Commands

- `make skills` — generate all outputs from `skills/*`
- `make skills-check` — verify outputs are up to date (CI gate)
- `make skills-clean` — remove generated outputs
- `make skill-new ID=<skill-id> NAME="<Skill Name>"` — scaffold a new canonical skill

## Developer Rules

- Never edit `.claude/agents/*` manually.
- Never edit `.codex/skills/*` manually.
- Always edit only `skills/*`.
- After any skill change, run `make skills` to refresh local outputs when needed.
- CI runs `make skills-check`; pull requests must keep generated outputs out of git.

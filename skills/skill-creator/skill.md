# Skill Creator

Create or update skills using this repository's canonical skill format.

Canonical source of truth is always `skills/<skill-id>/`.

## Workflow

1. Capture concrete user examples that should trigger the skill.
2. Decide whether this is a new skill or an update to an existing one.
3. For a new skill, scaffold with:
   - `make skill-new ID=<skill-id> NAME="<Skill Name>"`
4. Edit canonical files only:
   - `skills/<skill-id>/manifest.yml`
   - `skills/<skill-id>/skill.md`
   - `skills/<skill-id>/scripts/*` (optional)
5. Keep instructions concise and procedural; include only details not obvious to a capable coding agent.
6. Add scripts only when deterministic, repeatable execution is important.
7. Regenerate derived outputs:
   - `make skills`
8. Validate consistency:
   - `make skills-check`

## Canonical Rules

- Never edit generated outputs directly:
  - `.claude/agents/*`
  - `.codex/skills/*`
  - `SKILL.md`
- Keep `instructions.summary` in `manifest.yml` explicit enough to trigger when relevant.
- Keep `instructions.steps` concrete and ordered.

## Usage

Create a new skill:

```bash
make skill-new ID=example-skill NAME="Example Skill"
```

Regenerate outputs after edits:

```bash
make skills
make skills-check
```

## Edge Cases

- If `make skill-new` reports the skill already exists, treat the request as an update and edit existing files in `skills/<skill-id>/`.
- If a requested skill id includes unsupported characters, normalize to lowercase letters, numbers, hyphens, and underscores.
- If a change appears only in generated outputs, move the edit to canonical files and regenerate.

## Output and Artifacts

- Canonical files created or updated in `skills/<skill-id>/`.
- Generated local artifacts refreshed via `make skills`:
  - `.claude/agents/<skill-id>.md`
  - `.codex/skills/<skill-id>/SKILL.md`
  - `.codex/skills/<skill-id>/agents/openai.yaml`
  - `.codex/skills/<skill-id>/scripts/*` (if present)
  - `SKILL.md`

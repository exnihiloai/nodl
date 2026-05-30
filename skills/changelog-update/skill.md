# Changelog Update

Inspect the current feature branch, identify changes not yet documented, and write a user-friendly changelog entry following [Keep a Changelog](https://keepachangelog.com) and [Semantic Versioning](https://semver.org) conventions.

## Prerequisites

- Git repository with a `main` branch.
- `CHANGELOG.md` present at the repository root.
- Current branch is a feature branch (not `main`, not detached HEAD).

## Usage

Trigger examples:
- "update the changelog"
- "document what's new on this branch"
- "add a changelog entry for this feature"
- "what's not in the changelog yet?"
- "/changelog-update"

## Workflow

### Step 1 — Orientation

1. Run `git branch --show-current` to get the current branch name.
2. If already on `main`, warn the user and stop — there is nothing to diff.
3. Run `git log main..HEAD --oneline` to list commits on the feature branch not yet in main.
4. If there are no commits, stop and tell the user there is nothing to document.

### Step 2 — Understand what is already documented (lean read)

Read only the top portion of `CHANGELOG.md` until you have found:
- The `[Unreleased]` block (if any), AND
- The very first versioned section heading (e.g. `## [0.1.0] - 2026-02-21`).

Stop reading there. Everything under the first versioned heading is already released and documented. Anything in `[Unreleased]` is already documented but not yet versioned. Do not read further than necessary.

### Step 3 — Gather changes from the branch

Run these commands:
- `git diff main..HEAD --stat` for a high-level file overview.
- `git log main..HEAD --format="%s%n%b"` to get commit subjects and bodies.

Inspect changed files selectively — read only files relevant to user-visible behaviour: controllers, models, views, config, migrations. Skip test files, lock files, and auto-generated files unless they reveal a feature boundary.

Categorise each change into one of these buckets:

| Bucket | Description |
|---|---|
| **Added** | Brand-new capability for the user |
| **Changed** | Existing behaviour that works differently |
| **Fixed** | Something broken that now works |
| **Removed** | Something the user could use before and can no longer |
| **Technical** | Internal refactors, dependency updates, CI, performance not visible to end users |
| **Security** | Security-relevant changes (may be more technical) |

### Step 4 — Draft the changelog entry

Follow this style guide:

- **Non-technical language by default.** Assume the reader has never seen source code. Describe what the user can now do or what problem is solved, not how it is implemented.
  - Bad: "Refactored `AuthenticationController` to extract `authenticate!` concern."
  - Good: "Signing in is now faster and more reliable."
- **Active voice, present tense.** Start bullets with a verb: "You can now…", "The dashboard now shows…", "Fixed an issue where…".
- **Include value.** Each bullet should answer "so what?" — why does this matter to the user?
- **Technical and Security sections** may be more specific (file names, CVE references, dependency versions) because their audience is developers or security reviewers.
- **Do not document test-only, documentation-only, or CI-only changes** in user-facing sections; those belong in Technical if at all.

### Step 5 — Determine version and placement

Apply Semantic Versioning:

- **PATCH** bump (0.x.y → 0.x.y+1): only bug fixes.
- **MINOR** bump (0.x.0): new features or improvements, backwards-compatible.
- **MAJOR** bump (1.0.0+): breaking changes or major new capabilities.

If an `[Unreleased]` block already exists, add to it (supplement, do not duplicate). If the user asks for a version number explicitly, use that. If unsure about the version, ask the user before writing.

### Step 6 — Write to CHANGELOG.md

- If supplementing `[Unreleased]`: insert new bullets into the correct sub-sections.
- If creating a new versioned entry: insert it immediately after the `## [Unreleased]` block (or after the `# Changelog` header if no Unreleased block exists), using the format:

  ```
  ## [X.Y.Z] - YYYY-MM-DD
  ```

- Never reorder or delete existing entries.
- After writing, show the user the diff of the changes made.

## Edge Cases

- **Already on main:** Stop immediately, warn the user, do nothing.
- **No commits ahead of main:** Stop and tell the user there is nothing to document.
- **Unreleased block already contains the same change:** Skip that item, do not duplicate.
- **User specifies a version:** Use it exactly without further prompting.
- **User asks "what's not in the changelog yet?":** Run steps 1–3, list undocumented changes, and ask whether to write them before touching the file.
- **CHANGELOG.md does not exist:** Inform the user and offer to create it with the standard header before proceeding.

## Output and Artifacts

- Reads: `CHANGELOG.md` (top section only), `git log`, `git diff`.
- Writes: `CHANGELOG.md` (inserts or supplements a changelog entry).
- Shows: the updated CHANGELOG section and a short summary — "X new items documented across Y categories."

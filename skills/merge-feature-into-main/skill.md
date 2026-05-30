# Merge Feature Branch Into Main

Safely merge the current feature branch into `main` with a merge commit even when fast-forward would be possible.

## Workflow

1. Confirm repository status is fully clean.
2. Detect current branch as the feature branch.
3. Switch to `main`.
4. Pull latest `main` from `origin`.
5. Merge feature branch into `main` using `--no-ff`.
6. Ask whether to push; push `main` only on explicit confirmation.
7. Stop and report any problem with concrete next steps.

## Prerequisites

- Git repository has a local `main` branch.
- Remote `origin` is configured and reachable.
- Current branch is a feature branch (not `main` and not detached HEAD).
- Working tree is clean.

## Usage

```bash
skills/merge-feature-into-main/scripts/merge_feature_into_main.sh
```

## Edge Cases and Failure Handling

- Dirty working tree: stop and ask user to commit/stash/discard first.
- Detached HEAD or currently on `main`: stop and ask for clarification.
- `git pull` failure: stop and suggest fixing remote/auth/network first.
- Merge conflicts: stop, suggest resolving conflicts or aborting merge (`git merge --abort`).
- Push rejection: stop, report output, suggest pulling/rebasing or permission fix.

## Output and Artifacts

- Writes a merge commit on `main` (forced via `--no-ff`) when merge succeeds.
- Optionally pushes `main` to `origin` after explicit prompt.

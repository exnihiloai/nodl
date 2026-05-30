#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Error: $1" >&2
  exit 1
}

suggest() {
  echo "Suggestion: $1" >&2
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Not inside a git repository."
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

status_output="$(git status --porcelain)"
if [[ -n "$status_output" ]]; then
  echo "Issue: Working tree is not clean." >&2
  suggest "Commit, stash, or remove local changes and retry."
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" == "HEAD" ]]; then
  echo "Issue: Detached HEAD state detected." >&2
  suggest "Checkout your feature branch first, then rerun the script."
  exit 1
fi

if [[ "$current_branch" == "main" ]]; then
  echo "Issue: Current branch is already 'main'." >&2
  suggest "Checkout the feature branch you want to merge, then rerun."
  exit 1
fi

feature_branch="$current_branch"

echo "Feature branch detected: $feature_branch"

echo "Checking out main..."
git checkout main || {
  fail "Could not checkout main."
}

echo "Pulling latest main from origin..."
git pull origin main || {
  fail "Could not pull latest main from origin."
}

echo "Merging '$feature_branch' into 'main' with a merge commit (--no-ff)..."
if ! git merge --no-ff "$feature_branch"; then
  echo "Issue: Merge failed (likely conflicts)." >&2
  suggest "Resolve conflicts and run 'git merge --continue', or abort with 'git merge --abort'."
  exit 1
fi

echo "Merge completed successfully."

while true; do
  read -r -p "Push main to origin now? [y/N]: " answer
  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      echo "Pushing main to origin..."
      if git push origin main; then
        echo "Push completed successfully."
        exit 0
      fi

      echo "Issue: Push failed." >&2
      suggest "Check permissions/remote state, then push manually: git push origin main"
      exit 1
      ;;
    [Nn]|[Nn][Oo]|"")
      echo "Push skipped. main is merged locally and not pushed."
      exit 0
      ;;
    *)
      echo "Please answer 'y' or 'n'."
      ;;
  esac
done

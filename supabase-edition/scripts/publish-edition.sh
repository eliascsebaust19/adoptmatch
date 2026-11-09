#!/usr/bin/env bash
# Splits `supabase-edition/` into its own repository.
#
#   ./scripts/publish-edition.sh adoptmatch-supabase [owner]
#
# Run from the parent repository root. Nothing is pushed to the current branch's
# remote: `git subtree split` rewrites a temporary branch that contains only this
# folder, and that branch is pushed to the new repository.
set -euo pipefail

REPO_NAME="${1:-adoptmatch-supabase}"
OWNER="${2:-$(gh api user --jq .login)}"
FOLDER="supabase-edition"
SPLIT_BRANCH="supabase-edition-split"

if [[ ! -d "$FOLDER" ]]; then
  echo "✖ Run this from the repository root (no $FOLDER folder here)." >&2
  exit 1
fi

command -v gh >/dev/null || { echo "✖ gh CLI is required." >&2; exit 1; }
command -v git >/dev/null || { echo "✖ git is required." >&2; exit 1; }

echo "→ Splitting $FOLDER into $SPLIT_BRANCH"
git subtree split --prefix "$FOLDER" -b "$SPLIT_BRANCH" >/dev/null

echo "→ Creating $OWNER/$REPO_NAME"
if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  echo "• Repository already exists, pushing to it."
else
  gh repo create "$OWNER/$REPO_NAME" --private \
    --description "AdoptMatch backend on Supabase: Postgres + RLS + Edge Functions" >/dev/null
fi

git remote remove "$REPO_NAME" 2>/dev/null || true
git remote add "$REPO_NAME" "https://github.com/$OWNER/$REPO_NAME.git"

echo "→ Pushing"
git push "$REPO_NAME" "$SPLIT_BRANCH:main"

echo "✔ https://github.com/$OWNER/$REPO_NAME"
echo "  The temporary branch '$SPLIT_BRANCH' stays local; delete it with:"
echo "  git branch -D $SPLIT_BRANCH && git remote remove $REPO_NAME"

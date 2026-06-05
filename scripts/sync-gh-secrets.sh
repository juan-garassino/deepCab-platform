#!/usr/bin/env bash
# Bulk-upload GitHub Actions VARIABLES and SECRETS to all 3 deepCab repos
# from dotenv-style files. Uses native `gh variable set -f` / `gh secret set -f`.
#
# Files (relative to this script's parent dir):
#   scripts/gh-vars.env       — non-secret variables (visible in CI logs)
#   scripts/gh-secrets.env    — secrets (never logged; gitignored)
#
# Both are dotenv format:  KEY=VALUE  (one per line, no quotes, no spaces).
# Lines starting with #, and blank lines, are ignored by `gh`.
#
# Per-repo overrides (e.g. WEBSITE_API_BASE_URL only on the website repo) live
# in scripts/gh-vars.<repo-suffix>.env — the script appends them on top of the
# shared file when uploading to that repo.
#
# Usage:
#   gh auth status                                    # green?
#   cp scripts/gh-vars.env.example      scripts/gh-vars.env
#   cp scripts/gh-secrets.env.example   scripts/gh-secrets.env
#   $EDITOR scripts/gh-{vars,secrets}.env             # fill values
#   ./scripts/sync-gh-secrets.sh

set -euo pipefail

cd "$(dirname "$0")/.."

REPOS=(
  "juan-garassino/deepCab"
  "juan-garassino/deepCab-platform"
  "juan-garassino/deepCab-website"
)

SHARED_VARS="scripts/gh-vars.env"
SHARED_SECRETS="scripts/gh-secrets.env"

# Optional per-repo additions (suffix matches end of "owner/repo")
declare -A PER_REPO_VARS=(
  ["juan-garassino/deepCab"]="scripts/gh-vars.api.env"
  ["juan-garassino/deepCab-platform"]="scripts/gh-vars.platform.env"
  ["juan-garassino/deepCab-website"]="scripts/gh-vars.website.env"
)

for f in "$SHARED_VARS" "$SHARED_SECRETS"; do
  if [[ ! -f "$f" ]]; then
    echo "missing $f — copy from ${f}.example and fill it in." >&2
    exit 1
  fi
done

for repo in "${REPOS[@]}"; do
  echo
  echo "=== $repo ==="

  # 1. Shared variables
  echo "  vars (shared) <- $SHARED_VARS"
  gh variable set --repo "$repo" -f "$SHARED_VARS"

  # 2. Per-repo variables, if file exists
  extra="${PER_REPO_VARS[$repo]:-}"
  if [[ -n "$extra" && -f "$extra" ]]; then
    echo "  vars (repo)   <- $extra"
    gh variable set --repo "$repo" -f "$extra"
  fi

  # 3. Shared secrets
  echo "  secrets       <- $SHARED_SECRETS"
  gh secret set --repo "$repo" -f "$SHARED_SECRETS"
done

echo
echo "Done. Verify with:"
for repo in "${REPOS[@]}"; do
  echo "  gh variable list --repo $repo"
  echo "  gh secret list   --repo $repo"
done

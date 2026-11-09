#!/usr/bin/env bash
# Shared helpers for the repo-wide scripts (versioning, branch policy, CI cleanup).
# Source it; don't run it. Each app adds its own helpers on top, for example
# apps/ios/scripts/_common.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Added to the build number. Raise it once if App Store Connect ever already has a
# higher build number than the commit count gives (for example after a history rewrite).
BUILD_OFFSET=0

# Branch names allowed by the branching policy (see CLAUDE.md).
BRANCH_PATTERN='^(feature|fix|chore|docs|ci|refactor|test|claude)/[a-z0-9][a-z0-9._-]*$'

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# The iOS and Android apps share one version (scripts/version.sh). The website, in
# apps/web/, is versioned on its own, so changes that only touch it don't move the app
# version or appear in the apps' What to Test notes.
# Succeeds when the changes between two commits count towards the app version: anything
# outside apps/web/, or no changes at all.
#   counts_for_app_version <from> <to>
counts_for_app_version() {
  local f any=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    any=1
    [[ "$f" == apps/web/* ]] || return 0
  done < <(git diff --name-only "$1" "$2" 2>/dev/null)
  [[ $any -eq 0 ]]
}

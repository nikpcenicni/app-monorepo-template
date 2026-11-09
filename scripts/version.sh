#!/usr/bin/env bash
# Works out the app version from git, following the branching policy in CLAUDE.md.
# Nothing is stored: the same commit always gets the same version. The iOS and Android apps
# always share this version. The website (apps/web/) has its own, so a merge or branch that
# only changes apps/web/ is left out of the marketing version (see counts_for_app_version
# in _common.sh). It still adds a first-parent commit, so it raises the build number; that
# only matters in that build numbers keep increasing.
#
#   scripts/version.sh            "1.0 (6)"
#   scripts/version.sh marketing  "1.0"
#   scripts/version.sh build      "6"
#   scripts/version.sh explain    how the version was worked out
#
# Marketing version (CFBundleShortVersionString)
#   - Before the first App Store release (no v* tag): always 1.0.
#   - After it: start from the newest vX.Y.Z tag reachable from HEAD and look at every
#     branch merged into main since then (except website-only ones), plus the current branch if it isn't main and
#     any unmerged branches below it in a stacked PR (gh stack):
#       BREAKING CHANGE in a commit message  -> major (X+1.0.0)
#       feature/*                            -> minor (X.Y+1.0)
#       anything else (fix, chore, ...)      -> patch (X.Y.Z+1)
#   - HEAD exactly on a release tag: that tag's version.
#
# Build number (CFBundleVersion)
#   - Commits on HEAD's first-parent history, plus BUILD_OFFSET. On main this goes up
#     by one with every merge, so it always increases. Only main is uploaded.
set -euo pipefail
source "$(dirname "$0")/_common.sh"
cd "$REPO_ROOT"

INITIAL_VERSION="1.0"

build_number() {
  echo $(( $(git rev-list --count --first-parent HEAD) + BUILD_OFFSET ))
}

# Prints "<level> <reason>" lines for everything since the given tag.
change_levels() {
  local range="$1..HEAD"
  local c
  for c in $(git log --format=%H --grep="BREAKING CHANGE" "$range"); do
    if counts_for_app_version "$c^" "$c"; then
      echo "major BREAKING CHANGE in a commit message"
      break
    fi
  done
  git log --first-parent --format='%H %s' "$range" | while read -r sha subject; do
    counts_for_app_version "$sha^" "$sha" || continue
    local branch=""
    if [[ "$subject" =~ ^Merge\ pull\ request\ \#[0-9]+\ from\ [^/]+/(.+)$ ]]; then
      branch="${BASH_REMATCH[1]}"
    elif [[ "$subject" =~ ^Merge\ branch\ \'([^\']+)\' ]]; then
      branch="${BASH_REMATCH[1]}"
    fi
    if [[ -z "$branch" ]]; then
      echo "patch direct commit on main: $subject"
    elif [[ "$branch" == feature/* ]]; then
      echo "minor merged $branch"
    else
      echo "patch merged $branch"
    fi
  done
  local current
  current="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$current" != main && "$current" != HEAD ]]; then
    local base
    base="$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || true)"
    if [[ -n "$base" ]] && ! counts_for_app_version "$base" HEAD; then
      echo "none current branch $current only changes the website (apps/web/)"
      return 0
    fi
    if [[ "$current" == feature/* ]]; then echo "minor current branch $current"; else echo "patch current branch $current"; fi
    # Branches below this one in a stack land on main together with it.
    local trunk=main
    git rev-parse -q --verify origin/main >/dev/null && trunk=origin/main
    git rev-parse -q --verify "$trunk" >/dev/null || return 0
    git for-each-ref --format='%(refname:short)' --merged HEAD --no-merged "$trunk" refs/heads refs/remotes/origin \
      | sed 's#^origin/##' | { grep -vxE "HEAD|main|origin|$current" || true; } | sort -u | while IFS= read -r below; do
        [[ "$below" =~ $BRANCH_PATTERN ]] || continue
        counts_for_app_version "$(git merge-base "$below" "$trunk")" "$below" || continue
        if [[ "$below" == feature/* ]]; then echo "minor stacked below $below"; else echo "patch stacked below $below"; fi
      done
  fi
}

marketing_version() {
  local tag
  tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' HEAD 2>/dev/null || true)"
  if [[ -z "$tag" ]]; then
    echo "$INITIAL_VERSION"; return
  fi
  local base="${tag#v}" major minor patch
  IFS=. read -r major minor patch <<<"$base"
  if [[ "$(git rev-parse HEAD)" == "$(git rev-list -n1 "$tag")" ]]; then
    echo "$base"; return
  fi
  local levels
  levels="$(change_levels "$tag" | cut -d' ' -f1 | grep -v '^none$' || true)"
  if [[ -z "$levels" ]]; then
    echo "$base"; return
  fi
  if grep -q major <<<"$levels"; then
    echo "$((major + 1)).0.0"
  elif grep -q minor <<<"$levels"; then
    echo "$major.$((minor + 1)).0"
  else
    echo "$major.$minor.$((patch + 1))"
  fi
}

case "${1:-show}" in
  show)      echo "$(marketing_version) ($(build_number))" ;;
  marketing) marketing_version ;;
  build)     build_number ;;
  explain)
    tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' HEAD 2>/dev/null || true)"
    echo "Version: $(marketing_version) ($(build_number))"
    if [[ -z "$tag" ]]; then
      echo "No release tag yet, so the marketing version stays $INITIAL_VERSION until the first App Store release is tagged v1.0.0."
    else
      echo "Last release: $tag. Changes since then:"
      change_levels "$tag" | sed 's/^/  /'
    fi
    echo "Build number: $(git rev-list --count --first-parent HEAD) first-parent commits + offset $BUILD_OFFSET."
    ;;
  *) sed -n '2,26p' "$0"; exit 1 ;;
esac

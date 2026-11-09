#!/usr/bin/env bash
# Prints the "What to Test" notes for a TestFlight build: the "## What to Test" sections of
# the pull requests merged into main since the previous build/* tag, combined.
#
#   scripts/what-to-test.sh [<commit>]    (default HEAD)
#
# PRs that only change the website (apps/web/) are left out: the notes are for the apps.
# A merged PR with no such section contributes its title instead. Reads the PRs with `gh`
# (signed in, or GH_TOKEN), or, when `gh` can't be found, with curl and GH_TOKEN or
# GITHUB_TOKEN against the GitHub API. Without either, lists the merge commits' branch names,
# and says why on stderr (shown in the CI log). The result is cut to
# TestFlight's 4,000-character limit. scripts/set-testflight-notes.swift sends it to App
# Store Connect.
set -euo pipefail
source "$(dirname "$0")/_common.sh"
cd "$REPO_ROOT"

HEAD_REF="${1:-HEAD}"
# The previous upload: the newest build/* tag before this commit. It is looked up from the
# parent, so it still works after this commit has been tagged.
PREVIOUS="$(git describe --tags --match 'build/*' --abbrev=0 "$HEAD_REF^" 2>/dev/null || true)"
RANGE="${PREVIOUS:+$PREVIOUS..}$HEAD_REF"

PRS=()
while read -r sha subject; do
  counts_for_app_version "$sha^" "$sha" || continue
  if [[ "$subject" =~ ^Merge\ pull\ request\ \#([0-9]+) ]]; then PRS+=("${BASH_REMATCH[1]}"); fi
done < <(git log --first-parent --merges --reverse --format='%H %s' "$RANGE")

if [[ ${#PRS[@]} -eq 0 ]]; then
  echo "Bug fixes and improvements."
  exit 0
fi

# gh may be installed where a self-hosted runner's PATH doesn't reach.
GH=""
for candidate in "$(command -v gh 2>/dev/null || true)" /opt/homebrew/bin/gh /usr/local/bin/gh; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then GH="$candidate"; break; fi
done
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
# owner/name, from Actions or from the origin remote's URL.
REPO="${GITHUB_REPOSITORY:-$(git remote get-url origin 2>/dev/null | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')}"

BODIES="$(mktemp -d)"
trap 'rm -rf "$BODIES"' EXIT

# Writes PR $1's title and body as JSON to $2. Fails, with the reason on stderr, if it can't.
fetch_pr() {
  local pr="$1" out="$2" err
  if [[ -n "$GH" ]]; then
    if err="$("$GH" pr view "$pr" --repo "$REPO" --json title,body 2>&1 >"$out")"; then return 0; fi
    echo "what-to-test: gh couldn't read PR #$pr: $err" >&2
  fi
  if [[ -n "$TOKEN" && -n "$REPO" ]]; then
    if curl -fsS --retry 2 -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$REPO/pulls/$pr" -o "$out"; then return 0; fi
    echo "what-to-test: the GitHub API couldn't read PR #$pr" >&2
  elif [[ -z "$GH" ]]; then
    echo "what-to-test: no gh and no GH_TOKEN, so PR #$pr's notes can't be read" >&2
  fi
  return 1
}

for pr in "${PRS[@]}"; do
  if ! fetch_pr "$pr" "$BODIES/$pr.json"; then
    # No GitHub access: fall back to the branch name in the merge commit.
    branch="$(git log --first-parent --merges --format=%s "$RANGE" | sed -n "s/^Merge pull request #$pr from [^/]*\///p" | head -1)"
    printf '{"title": "%s", "body": ""}' "${branch//\"/}" >"$BODIES/$pr.json"
  fi
done

python3 - "$BODIES" "${PRS[@]}" <<'PY'
import json, os, re, sys

folder, prs = sys.argv[1], sys.argv[2:]
LIMIT = 4000
heading = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")

def section(body):
    """The lines under a 'What to Test' heading, up to the next heading of any level."""
    lines, found = [], False
    for line in body.replace("\r\n", "\n").split("\n"):
        m = heading.match(line)
        if m:
            if found:
                break
            found = m.group(1).strip().lower() in ("what to test", "what to test:")
            continue
        if found:
            lines.append(line.rstrip())
    text = "\n".join(lines).strip()
    # TestFlight shows plain text: drop Markdown emphasis and code marks, keep the bullets.
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"^\s*[*+]\s+", "- ", text, flags=re.M)
    return text

parts = []
for pr in prs:
    with open(os.path.join(folder, f"{pr}.json")) as f:
        data = json.load(f)
    notes = section(data.get("body") or "")
    if not notes:
        title = (data.get("title") or "").strip()
        notes = f"- {title}" if title else ""
    if notes and notes not in parts:
        parts.append(notes)

text = "\n\n".join(parts) or "Bug fixes and improvements."
if len(text) > LIMIT:
    text = text[: LIMIT - 1].rsplit("\n", 1)[0].rstrip() + "\n…"
print(text)
PY

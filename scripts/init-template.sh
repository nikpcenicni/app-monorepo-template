#!/usr/bin/env bash
# Turns this template into a new project: fills in every __PLACEHOLDER__, optionally removes
# the game-services agents, then deletes TEMPLATE.md and this script. Run it once, from a
# fresh copy of the template, before the first commit of the new project.
#
#   scripts/init-template.sh                      ask for each value
#   scripts/init-template.sh --name "Acme Notes" --description "A calm notes app." \
#     --bundle-id dev.example.acmenotes --team-id ABCDE12345 \
#     --owner "Example Ltd" --owner-url https://example.com [--slug acme-notes] \
#     [--target AcmeNotes] [--no-game-services] [--yes]
#
# Placeholders:
#   __PROJECT_NAME__         display name                   Acme Notes
#   __PROJECT_SLUG__         lowercase, hyphens             acme-notes      (runner label, web package)
#   __APP_TARGET__           Xcode project/scheme name      AcmeNotes
#   __PROJECT_DESCRIPTION__  one sentence                   A calm notes app.
#   __BUNDLE_ID__            iOS bundle ID / Android app ID dev.example.acmenotes
#   __APPLE_TEAM_ID__        Apple Developer team ID        ABCDE12345      (leave empty to fill in later)
#   __OWNER_NAME__           website footer credit          Example Ltd
#   __OWNER_URL__            website footer link            https://example.com
#   __YEAR__                 website footer year            this year
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }

NAME="" SLUG="" TARGET="" DESCRIPTION="" BUNDLE_ID="" TEAM_ID="" OWNER="" OWNER_URL=""
GAME_SERVICES="" YES=0 TEAM_ID_SET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; TEAM_ID_SET=1; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --owner-url) OWNER_URL="$2"; shift 2 ;;
    --no-game-services) GAME_SERVICES=no; shift ;;
    --game-services) GAME_SERVICES=yes; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) die "Unknown option $1 (see --help)" ;;
  esac
done

[[ -f TEMPLATE.md ]] || die "TEMPLATE.md is missing, so this copy was already initialised."

ask() { # ask <var> <prompt> <default>
  local var="$1" prompt="$2" default="${3:-}" reply
  [[ -n "${!var}" ]] && return
  if [[ ! -t 0 ]]; then printf -v "$var" '%s' "$default"; return; fi
  read -r -p "$prompt${default:+ [$default]}: " reply
  printf -v "$var" '%s' "${reply:-$default}"
}

ask NAME "Project name (display)" ""
[[ -n "$NAME" ]] || die "A project name is required (--name)."
ask SLUG "Slug (lowercase, hyphens)" "$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
ask TARGET "Xcode target and scheme name" "$(printf '%s' "$NAME" | sed -E 's/[^A-Za-z0-9]//g')"
ask DESCRIPTION "One-sentence description" "$NAME is an app for iPhone, iPad and Android."
ask BUNDLE_ID "Bundle ID / application ID" "dev.example.$(printf '%s' "$SLUG" | tr -d '-')"
if [[ $TEAM_ID_SET -eq 0 ]]; then ask TEAM_ID "Apple team ID (empty to fill in later)" ""; fi
ask OWNER "Owner name for the website footer" "$NAME"
ask OWNER_URL "Owner URL for the website footer" "https://example.com"
ask GAME_SERVICES "Is it a game that will use Game Center / Play Games? (yes/no)" "no"

[[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Slug '$SLUG' must be lowercase letters, digits and hyphens."
[[ "$TARGET" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || die "Xcode target '$TARGET' must start with a letter and contain only letters and digits."
[[ "$BUNDLE_ID" =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$ ]] || die "Bundle ID '$BUNDLE_ID' must look like dev.example.app (letters, digits, underscores; no hyphens, which Android rejects)."
[[ -z "$TEAM_ID" || "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Apple team ID '$TEAM_ID' should be 10 uppercase letters and digits."
[[ "$OWNER_URL" =~ ^https?:// ]] || die "Owner URL '$OWNER_URL' must start with http:// or https://."
case "$GAME_SERVICES" in y|yes) GAME_SERVICES=yes ;; n|no) GAME_SERVICES=no ;; *) die "Answer yes or no for game services." ;; esac

cat >&2 <<EOF

  Project name   $NAME
  Slug           $SLUG
  Xcode target   $TARGET
  Description    $DESCRIPTION
  Bundle ID      $BUNDLE_ID
  Apple team ID  ${TEAM_ID:-(fill in later: __APPLE_TEAM_ID__ stays in place)}
  Owner          $OWNER ($OWNER_URL)
  Game services  $GAME_SERVICES

EOF
if [[ $YES -eq 0 && -t 0 ]]; then
  read -r -p "Apply? [y/N] " reply
  [[ "$reply" =~ ^[Yy] ]] || die "Cancelled; nothing changed."
fi

# Every text file except git internals and this script.
files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(
  find . -path ./.git -prune -o -type f ! -name 'init-template.sh' ! -name '*.png' ! -name '*.jpg' -print0)

export P_NAME="$NAME" P_SLUG="$SLUG" P_TARGET="$TARGET" P_DESCRIPTION="$DESCRIPTION" \
  P_BUNDLE_ID="$BUNDLE_ID" P_TEAM_ID="$TEAM_ID" P_OWNER="$OWNER" P_OWNER_URL="$OWNER_URL" \
  P_YEAR="$(date +%Y)"

log "Filling in placeholders in ${#files[@]} files"
perl -pi -e '
  s/__PROJECT_NAME__/$ENV{P_NAME}/g;
  s/__PROJECT_SLUG__/$ENV{P_SLUG}/g;
  s/__APP_TARGET__/$ENV{P_TARGET}/g;
  s/__PROJECT_DESCRIPTION__/$ENV{P_DESCRIPTION}/g;
  s/__BUNDLE_ID__/$ENV{P_BUNDLE_ID}/g;
  s/__APPLE_TEAM_ID__/$ENV{P_TEAM_ID}/g if length $ENV{P_TEAM_ID};
  s/__OWNER_NAME__/$ENV{P_OWNER}/g;
  s/__OWNER_URL__/$ENV{P_OWNER_URL}/g;
  s/__YEAR__/$ENV{P_YEAR}/g;
' "${files[@]}"

if [[ "$GAME_SERVICES" == no ]]; then
  log "Removing the game-services agents (gamekit-specialist, play-games-specialist)"
  rm -f .claude/agents/gamekit-specialist.md .claude/agents/play-games-specialist.md
  perl -0pi -e '
    s/^  \| Game services \(games only; delete if unused\) \|[^\n]*\n//m;
    s/`gamekit-specialist`, `play-games-specialist`, //g;
    s/; `gamekit-specialist` for Game Center//g;
    s/; `play-games-specialist` for Play Games Services//g;
    s/ \/ gamekit-specialist \(games\)//g;
    s/ \/ play-games-specialist \(games\)//g;
    s/^\| `gamekit-specialist` \|[^\n]*\n//m;
    s/^\| `play-games-specialist` \|[^\n]*\n//m;
    s/, `gamekit-specialist` handles Game Center \(games only\)//g;
    s/, `play-games-specialist` handles Play Games Services \(games only\)//g;
  ' CLAUDE.md .claude/skills/ship/SKILL.md docs/development-workflow.md apps/ios/README.md apps/android/README.md
  if left="$(grep -rln -e 'gamekit-specialist' -e 'play-games-specialist' --exclude-dir=.git --exclude=init-template.sh --exclude=TEMPLATE.md . )"; then
    echo "Still mentioned (edit by hand): $left" >&2
  fi
else
  perl -pi -e 's/ \(games only; delete if unused\)//' CLAUDE.md
fi

chmod +x scripts/*.sh apps/ios/scripts/*.sh .githooks/pre-push
rm -f TEMPLATE.md

if left="$(grep -rlE '__[A-Z_]+__' --exclude-dir=.git --exclude=init-template.sh .)"; then
  log "Placeholders still to fill in by hand:"
  grep -rnoE '__[A-Z_]+__' --exclude-dir=.git --exclude=init-template.sh . | sort -u >&2
fi
rm -f scripts/init-template.sh

log "Done. Next:"
cat >&2 <<EOF
  git add -A && git commit -m "Start $NAME from the app monorepo template"
  git config core.hooksPath .githooks
  gh extension install github/gh-stack
  Create the GitHub repo, allow merge commits only, and push main.
  Setup for the runner, secrets and Claude is in docs/development-workflow.md.
EOF

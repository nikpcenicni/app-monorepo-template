#!/usr/bin/env bash
# Shared helpers for the iOS build scripts. Source it; don't run it.
# Builds on the repo-wide helpers in scripts/_common.sh (REPO_ROOT, BUILD_OFFSET,
# BRANCH_PATTERN, log, die).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/_common.sh"

IOS_ROOT="$REPO_ROOT/apps/ios"
PROJECT="$IOS_ROOT/__APP_TARGET__.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
SCHEME="__APP_TARGET__"
TEAM_ID="__APPLE_TEAM_ID__"
# Repo-wide version script: the marketing version and build number come from git.
VERSION_SH="$REPO_ROOT/scripts/version.sh"

# xcodebuild needs a full Xcode. If xcode-select points at the Command Line Tools,
# use the newest Xcode in /Applications for this process only.
ensure_xcode() {
  if xcodebuild -version >/dev/null 2>&1; then return; fi
  local xc
  xc=$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)
  [[ -n "$xc" ]] || die "No Xcode found in /Applications"
  export DEVELOPER_DIR="$xc/Contents/Developer"
  xcodebuild -version >/dev/null 2>&1 || die "Xcode at $xc is not usable"
  log "Using $(xcodebuild -version | head -1) from $xc"
}

# Prints the UDID of an available iPhone simulator, preferring the given name.
pick_simulator() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
match = [d for d in devices if d["name"] == name] or [d for d in devices if d["name"].startswith("iPhone")]
if not match:
    sys.exit("no iPhone simulator available")
print(match[-1]["udid"])
' "${1:-iPhone 16 Pro}"
}

# App Store Connect API key, used when set (always in CI; optional locally, where
# the Apple ID signed in to Xcode is used instead).
#   ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH (path to AuthKey_XXXX.p8)
asc_auth_args() {
  if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
    printf '%s\n' -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  fi
}

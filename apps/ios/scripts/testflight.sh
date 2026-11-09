#!/usr/bin/env bash
# Archives the iOS app and uploads it to App Store Connect, where it appears in TestFlight.
#
#   apps/ios/scripts/testflight.sh [--skip-tests] [--archive-only] [--tag]
#
#   --skip-tests    don't run the unit tests before archiving
#   --archive-only  archive and sign but don't upload. Works on any branch; use it to check signing.
#   --tag           after uploading, create and push the tag build/<N> on the uploaded commit
#
# The version comes from scripts/version.sh at the repo root (worked out from git, see CLAUDE.md) and is
# passed to xcodebuild. project.pbxproj is never edited. Uploads are only allowed from a
# clean main that matches origin/main, so every build number maps to one commit.
#
# Signing is automatic: the Apple ID signed in to Xcode and the local Apple Distribution
# certificate. To upload with an API key instead, set ASC_KEY_ID, ASC_ISSUER_ID and
# ASC_KEY_PATH (see apps/ios/scripts/_common.sh).
#
# Writes the result to apps/ios/build/testflight-result.txt for other tools to read.
set -euo pipefail
source "$(dirname "$0")/_common.sh"

RUN_TESTS=1; ARCHIVE_ONLY=0; TAG=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests) RUN_TESTS=0; shift ;;
    --archive-only) ARCHIVE_ONLY=1; shift ;;
    --tag) TAG=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) die "Unknown option $1 (version bumps are no longer options; see scripts/version.sh)" ;;
  esac
done

ensure_xcode
cd "$IOS_ROOT"

if [[ $ARCHIVE_ONLY -eq 0 ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$BRANCH" == main ]] || die "TestFlight uploads only come from main (on '$BRANCH'). Merge the PR first; the TestFlight workflow uploads on merge."
  [[ -z "$(git status --porcelain)" ]] || die "Working tree has changes. Uploads must match a pushed commit."
  git fetch -q origin main
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main differs from origin/main. Pull or push first."
fi

MARKETING="$("$VERSION_SH" marketing)"
BUILD="$("$VERSION_SH" build)"
VERSION="$MARKETING ($BUILD)"
log "Version $VERSION"

if [[ $RUN_TESTS -eq 1 ]]; then
  "$IOS_ROOT/scripts/test.sh"
fi

ARCHIVE="build/__APP_TARGET__.xcarchive"
EXPORT_DIR="build/export"
LOGS="build/logs"
rm -rf "$ARCHIVE" "$EXPORT_DIR"; mkdir -p "$LOGS"
AUTH=(); while IFS= read -r a; do AUTH+=("$a"); done < <(asc_auth_args)

log "Archiving (log: $LOGS/archive.log)"
if ! xcodebuild \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$MARKETING" CURRENT_PROJECT_VERSION="$BUILD" \
  archive >"$LOGS/archive.log" 2>&1; then
  grep -E "error:|Provisioning|signing" "$LOGS/archive.log" | sort -u | tail -30 >&2
  die "Archive failed. See $LOGS/archive.log"
fi

if [[ $ARCHIVE_ONLY -eq 1 ]]; then
  log "Archived $VERSION to $ARCHIVE (not uploaded)"
  exit 0
fi

# manageAppVersionAndBuildNumber=false keeps the numbers from the project, so git
# stays the record of what was uploaded.
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

log "Uploading to App Store Connect (log: $LOGS/upload.log)"
if ! xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} >"$LOGS/upload.log" 2>&1; then
  grep -E "error|Error|ITMS-" "$LOGS/upload.log" | sort -u | tail -30 >&2
  if grep -q -E "bundle version must be higher|ITMS-4238|already been used" "$LOGS/upload.log"; then
    echo "Hint: build $BUILD was already uploaded. If this commit was uploaded before, there's nothing to do. Otherwise raise BUILD_OFFSET in scripts/_common.sh in a chore/ PR." >&2
  fi
  die "Upload failed. See $LOGS/upload.log"
fi

if [[ $TAG -eq 1 ]]; then
  git tag -a "build/$BUILD" -m "TestFlight $VERSION"
  git push -q origin "build/$BUILD"
  log "Tagged build/$BUILD"
fi

echo "uploaded $VERSION from $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD) at $(date -u +%FT%TZ)" > build/testflight-result.txt
log "Uploaded $VERSION. It shows in TestFlight after App Store Connect finishes processing (usually 5-15 minutes)."

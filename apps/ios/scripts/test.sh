#!/usr/bin/env bash
# Builds the iOS app and runs the unit tests in the iOS Simulator.
# Usage: apps/ios/scripts/test.sh ["iPhone 16 Pro"]
# Prints only errors, test failures and the summary. Full log: apps/ios/build/logs/test.log
set -euo pipefail
source "$(dirname "$0")/_common.sh"
ensure_xcode
cd "$IOS_ROOT"
mkdir -p build/logs

UDID=$(pick_simulator "${1:-iPhone 16 Pro}")
log "Testing on simulator $UDID"

# Boot the simulator if needed and wait until it's ready. After a reboot or an Xcode
# update it starts cold, and launching the test host on a half-booted simulator fails
# with "Application failed preflight checks" (Busy).
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

set +e
xcodebuild \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test >build/logs/test.log 2>&1
status=$?
set -e

grep -E "error:|Test Case .* failed" build/logs/test.log | sort -u | head -60 || true
grep -E "Executed [0-9]+ test" build/logs/test.log | tail -1 || true
grep -E "\*\* TEST" build/logs/test.log | tail -1 || true
if [[ $status -ne 0 ]]; then
  die "Tests failed (exit $status). See apps/ios/build/logs/test.log"
fi
log "Tests passed"

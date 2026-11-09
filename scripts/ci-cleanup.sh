#!/usr/bin/env bash
# Removes the build output a CI job leaves on the self-hosted Mac: build/ and dist/ at the
# repo root and in each app under apps/, and the app's DerivedData. Run as the last step of every job on that
# runner, with `if: always()`. Safe to run when there's nothing to remove.
#
# The runner runs one job at a time, so nothing else is using these files.
set -uo pipefail

cd "$(dirname "$0")/.."
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

before=$(df -k "$HOME" | awk 'NR==2 {print $4}')

# Workspace build output: DerivedData, archives, exports, IPAs, logs. Upload any artifacts
# before this step runs.
rm -rf build dist apps/*/build apps/*/dist

# DerivedData that xcodebuild wrote to the default location (archives without
# -derivedDataPath, or older workflow versions). Only this project's folders are removed.
rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/__APP_TARGET__-*

# Simulators are left as they are: jobs reuse them, and a booted one saves a cold boot
# on the next test run.

after=$(df -k "$HOME" | awk 'NR==2 {print $4}')
freed=$(( (after - before) / 1024 ))
# Other processes write to the disk too, so the difference can come out slightly negative.
(( freed < 0 )) && freed=0
log "Cleanup freed about $freed MB; $(( after / 1024 / 1024 )) GB free"
exit 0

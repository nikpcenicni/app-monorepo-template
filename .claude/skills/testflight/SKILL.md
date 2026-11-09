---
name: testflight
description: Uploads __PROJECT_NAME__'s main branch to TestFlight, by starting the TestFlight workflow or, if asked to run it locally, with apps/ios/scripts/testflight.sh. The version comes from git under the branching policy; nothing is bumped by hand. Use for "/testflight", "push a build to TestFlight", or "cut a build".
argument-hint: "[local]"
---

# Upload main to TestFlight

Uploads only come from `main` (branching policy in `CLAUDE.md`). Never bump or edit version numbers; `scripts/version.sh` works them out from git.

0. If `apps/ios/__APP_TARGET__.xcodeproj` doesn't exist on `origin/main`, there is no iOS app to upload yet. Say so and stop.
1. Show what would be uploaded: `git fetch origin` and `git log -1 --oneline origin/main`. For its version, run `scripts/version.sh explain` while on an up-to-date `main` (switch only if the tree is clean; never overwrite local changes).
2. If `git tag --points-at origin/main` already lists a `build/*` tag, that commit is already in TestFlight. Say so and stop.
3. **Default (CI):** `gh workflow run TestFlight --ref main`. Wait a few seconds, then report the run link from `gh run list --workflow TestFlight -L 1`. The self-hosted runner builds, tests and uploads.
4. **`local`** (when the runner is down): `git checkout main && git pull --ff-only`, then run `apps/ios/scripts/testflight.sh --tag` with a 10-minute timeout. It refuses a dirty tree or a `main` that differs from `origin/main`.
5. On failure, read the log it names (`apps/ios/build/logs/`, or `gh run view --log-failed` for CI) and follow `.claude/agents/build-doctor.md`. Fixes go through a `fix/` or `ci/` branch and a PR, never straight onto `main`.
6. Report the version, e.g. "1.0 (8)", and the build's What to Test notes. The CI workflow collects them from the `## What to Test` sections of the PRs merged since the previous `build/*` tag (`scripts/what-to-test.sh`) and sets them on the build when the App Store Connect API key secrets exist; otherwise they're in the run summary to paste. After a **local** upload, print them with `scripts/what-to-test.sh`, and if `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH` are set, send them with `swift apps/ios/scripts/set-testflight-notes.swift <notes file> "$(scripts/version.sh marketing)" "$(scripts/version.sh build)"`. Otherwise give them to the user to paste (App Store Connect → TestFlight → the build → Test Details).

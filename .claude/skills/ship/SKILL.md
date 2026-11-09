---
name: ship
description: Takes a feature or fix request for __PROJECT_NAME__ from description to a merged PR, following the branching policy. Works out which apps it touches (iOS and Android together by default, or the website), writes one shared spec, builds each app in parallel with its own specialist sub-agents in separate worktrees, tests and reviews each app, checks iOS and Android still match, opens one PR, and (with --merge) merges it so the TestFlight workflow uploads it. Use when the user says "/ship <feature>", "build X and send it to TestFlight", or "ship it".
argument-hint: "<what to build or fix> [--ios-only | --android-only | --web] [--merge]"
---

# Ship a change

The request: **$ARGUMENTS**

Work through these steps in order. The user may be on their phone, so don't stop to ask questions you can answer with a sensible default. Note your assumptions in the PR. Stop and ask only if the request is ambiguous in a way that changes what gets built, or if a step needs the user (Apple ID or Play Console setup, secrets, approving a new dependency).

You are the orchestrator. The specialist agents write the code; you choose them, give them the spec, bring their work together on one branch, and own the commits and the PR.

## 1. Scope
Decide which apps the change touches, and say so in one line before starting:

| Request | Apps |
| --- | --- |
| Features, UI, settings, rules, a bug users see (the default) | **iOS and Android**: the same feature on both, in one PR |
| `--ios-only`, or it only makes sense on iOS (an Apple-only service, iPad keyboard, an iOS-only bug) | iOS |
| `--android-only`, or it only makes sense on Android (system back, a Google-only service, an Android-only bug) | Android |
| `--web`, or it's about the home page (download links, contact, about) | Website |
| Repo tooling, CI, docs, agents | None of the apps; do it directly |

- **An app not started yet:** if `apps/ios/__APP_TARGET__.xcodeproj` or `apps/android/settings.gradle.kts` doesn't exist, that app has no code, so a feature can't be added to it. Build the other app only and mark the feature **Pending** in `docs/feature-parity.md`. If neither exists, or the request is to start an app, see **Starting an app** at the end.
- **A one-platform bug:** fix it where it is, then check whether the other app has the same bug (`parity-reviewer` in step 6 will look too). If it does, fix both in this PR.
- **The website** is versioned separately and left out of the app version. Don't mix website work into an app branch unless it's copy that describes this same feature (step 6).

## 2. Prepare
- `git status`: if the tree is dirty with unrelated changes, stop and report them. Don't stash or discard someone's work.
- Pick the branch type from the branching policy in `CLAUDE.md`: `feature/` for new user-visible behavior, `fix/` for bugs, `chore/`/`docs/`/`ci/`/`refactor/`/`test/` otherwise. If the request mixes kinds, do the main one and list the rest as follow-ups. One branch covers every app the change touches: iOS and Android share a version, so a feature on both is still one `feature/` branch and one PR.
- If other agents may be working in this repo at the same time, work in your own git worktree (`EnterWorktree`) so you don't share a checkout.
- If the change depends on a branch that hasn't merged yet, stack it on that branch instead of starting from `main`: `gh stack checkout <that branch or PR>` (or `gh stack init <that branch>` if it isn't in a stack yet), then `gh stack add <type>/<short-kebab-slug>` from the top of the stack.
- Otherwise: `git checkout main && git pull --ff-only`, then `git checkout -b <type>/<short-kebab-slug>`. Inside GitHub Actions, the action starts you on a `feature/…` branch. If the work is a fix or chore, create a correctly named branch from it and push that instead.
- Read `CLAUDE.md`, the `CLAUDE.md` of each app in scope (`apps/ios/CLAUDE.md`, `apps/android/CLAUDE.md`, `apps/web/CLAUDE.md`), and only the code the change touches, on each side.

## 3. Spec and plan
Unless the change is small and obvious (one or two files per app, no new rules or screens), run the `Plan` agent with `model: "opus"`. Give it the request, the files you found on each side and the code rules of each app in scope. Ask it for:

1. **A shared spec** (iOS and Android both in scope): the behavior in plain words; every rule and number (thresholds, timings, limits); the exact user-facing strings; settings with their keys and defaults; accessibility behavior (labels, actions, announcements, reduced motion); and the **test cases**, each with its setup and expected result, which both apps will implement. This is the contract that keeps the apps the same.
2. **A plan per app**: files to change, the logic/UI split (`apps/ios/__APP_TARGET__/Core/` vs `Views/`; `apps/android/core/` vs `app/`), and where one app needs to catch up with the other first.

For a small change, write the shared spec yourself in a few lines. Either way, keep the spec: every implementer and reviewer gets it, and it goes in the PR.

## 4. Build it
Pick the implementer for each app:

| App | Implementer |
| --- | --- |
| iOS | `swift-engineer`; `gamekit-specialist` for Game Center |
| Android | `kotlin-engineer`; `play-games-specialist` for Play Games Services |
| Website | `web-engineer` |

For a fix, ask the implementer for a regression test. Small, single-file changes can be made directly instead of delegating.

**One app in scope:** run its implementer in this checkout, with the request, the spec, the plan and the files you found.

**Two or more apps in scope (the usual iOS + Android case):** build them in parallel, each in its own worktree, so no two agents share a checkout (branching policy rule 8):
1. Commit anything you've changed so far, and note the branch tip: `BASE=$(git rev-parse HEAD)`.
2. In **one message**, start one Agent call per app with `isolation: "worktree"`. Each prompt has the request, the shared spec, that app's plan and files, and these instructions:
   - Start from `$BASE`: if `git rev-parse HEAD` isn't `$BASE`, run `git reset --hard $BASE` (the worktree is new, so nothing is lost).
   - Change only your app's folder (`apps/ios/`, `apps/android/` or `apps/web/`). Leave shared docs to the orchestrator.
   - Run your app's tests (`apps/ios/scripts/test.sh` or `apps/android/scripts/test.sh`) until they pass.
   - Commit your work in the worktree, in the repo's commit style (imperative, sentence case, no prefix), and report the worktree path, branch and commits.
3. When both are done, bring their commits onto the feature branch in a fixed order, iOS first: `git cherry-pick $BASE..<their branch>`. The apps live in different folders, so these don't conflict; if one does, an agent strayed outside its folder: keep the change that belongs to that app's folder and redo the rest yourself.
4. Remove each worktree and its branch: `git worktree remove <path>` and `git branch -D <their branch>`.
5. If an implementer couldn't meet the spec on its platform, decide now: change the spec for both, or accept a platform difference and note it for the PR and `docs/feature-parity.md`.

## 5. Test
For each app in scope, after step 4:
- **iOS:** if `Core/` changed, run `test-engineer` to write the tests if the implementer didn't, or to review the ones added for missing edge cases and weak assertions, and to check every test case in the spec is covered. `apps/ios/scripts/test.sh` must pass. Toolchain or signing failures go to `build-doctor`.
- **Android:** if `core` changed, run `android-test-engineer` the same way, and also to check the new Kotlin tests mirror the iOS ones. `apps/android/scripts/test.sh` must pass. Gradle, SDK or JDK failures go to `android-build-doctor`.
- **Website:** the checks in `web-engineer` (markup, links, contrast, 320px).

When both test agents need to edit, run them in parallel in worktrees and bring their commits in as in step 4. Then run both test scripts on the feature branch (they can run at the same time, in the background). If a test script can't run on this machine at all (for example no Android SDK) and the build doctor says it needs the user, say so in the PR and the report, and don't merge.

## 6. Review
Run the reviewers in parallel (one message, several Agent calls) on `git diff main...HEAD`. Give each the shared spec. Ask the editing reviewers for findings only ("audit only"), so no two agents edit the same checkout:

| Reviewer | When |
| --- | --- |
| `accessibility-auditor` (audit only), naming the platforms | Any UI change: `apps/ios/__APP_TARGET__/Views/`, `apps/android/app/`, `apps/web/` |
| `swiftui-design-reviewer` | An iOS view changed |
| `compose-design-reviewer` | An Android composable changed. Tell it the change also landed on iOS, if it did |
| `parity-reviewer` | iOS and Android both changed, or a one-platform fix may affect the other app |
| `app-store-compliance` | iOS change touches data storage, networking, purchases, permissions, Apple services or metadata |
| `play-store-compliance` | Android change touches data, purchases, ads, networking, permissions, Google services, the manifest or `targetSdk` |

Fix every "Must fix", "Blocker", "Will be rejected" and parity **Mismatch** yourself, or hand it back to that app's implementer. Fix "Should fix", "Major" and **Missing** findings when the fix is small. Run each changed app's test script again afterwards.

Then run **`docs-keeper`**, always, on its own once the code is final. It updates the App Store listing, the Play Store listing, `docs/feature-parity.md`, the READMEs and the other docs. If it reports stale website copy for a user-visible feature, have `web-engineer` update `apps/web/index.html` on this branch.

## 7. Commit and open a PR
- Commit in logical pieces with clear messages, in the repo's style (imperative, sentence case, e.g. "Add a pause button to the timer"). Keep each app's code in its own commits. If saved data or settings won't carry over on either app, add `BREAKING CHANGE: <what>` to a commit body.
- If this branch is part of a stack, update it with `gh stack sync --accept-base-change` (never merge `main` into it). Then run `gh stack submit --auto --open` to push every layer and open or link the PRs. Edit this layer's PR with `gh pr edit` so its description has the details below.
- Otherwise run `git push -u origin HEAD`, then `gh pr create --base main` with:
  - a `## What to Test` section (below);
  - the apps it changes, and what changed in each;
  - the shared spec (short), and any accepted platform differences;
  - how each app was tested (the test result lines);
  - the accessibility, design, parity and compliance review results;
  - the docs updated, and any App Store Connect or Play Console fields to paste by hand (from `docs-keeper`);
  - new dependencies that need the user's approval, assumptions made, and anything to check on a device;
  - the output of `scripts/version.sh explain` (the version this merge will ship as, shared by both apps).
- **`## What to Test`** goes in every PR description, exactly under that heading. The TestFlight workflow copies it into the uploaded build's What to Test text (`scripts/what-to-test.sh`), and the same text will go to Play testers, so write it for testers, not reviewers:
  - 2–5 bullets starting with `- `, each one thing to try and what should happen.
  - Plain words a user knows: no file names, type names, code, links or PR jargon. Plain text only, since TestFlight doesn't render Markdown.
  - The same on both apps, so write it once. If one step differs, start that bullet with "iPhone and iPad:" or "Android:".
  - Under 1,000 characters, since several PRs can share one build and TestFlight allows 4,000 in total.
  - For a change users can't see (`chore/`, `ci/`, `docs/`, `refactor/`, `test/`), or a website-only change, write `- Nothing new to test.` If it touches app code, say what to recheck instead.
  - If the PR is edited later, keep this section in step: the text is read when the build uploads.

## 8. Merge and upload
Uploads only come from `main` (branching policy), so never run `apps/ios/scripts/testflight.sh` or an Android upload on the feature branch.
- With `--merge`: wait for the PR's checks (`gh pr checks --watch`). If they pass, merge with `gh pr merge --merge --delete-branch` (a merge commit, never squash). For a stacked PR, merge the stack one layer at a time from the bottom: `gh stack merge <bottom-pr> --merge -y`, wait for the next PR to retarget to `main` and pass its checks, then merge it the same way, up to this PR. Merging several layers in one call lands them in a single merge commit named after the top branch, which hides the lower branches from `scripts/version.sh`.
  - iOS code changed: the TestFlight workflow builds and uploads on the self-hosted runner. Report the run with `gh run list --workflow TestFlight -L 1`.
  - Android code changed: if an Android upload workflow exists, report its run the same way. If not, say the Android build has no upload path yet.
  - Website only: nothing uploads unless a deploy workflow exists.
- Without `--merge`: stop at the PR. Merging it (from the GitHub app is fine) triggers the uploads.

## 9. Report
Keep it short, since it may be read on a phone:
- One line on what was built, and on which apps.
- PR link.
- The version it ships as, e.g. "1.0 (8)", and whether the TestFlight run started or is waiting on the merge.
- The PR's What to Test bullets.
- Platform differences and anything left **Pending** in `docs/feature-parity.md`.
- Anything the user must do by hand (App Store Connect, Play Console, approving a dependency).

## Starting an app
A request to start an app ("Start the iOS app", "Port __PROJECT_NAME__ to Android") is too big for one PR. Build it as a stack, one layer per PR, each a policy-named branch on the one below, in this order:
1. **iOS:** the Xcode project has to be created in Xcode by the user with the names in `apps/ios/CLAUDE.md` (a hand-written `project.pbxproj` is fragile). Ask for it, then open `chore/ios-project` with the empty project, a placeholder screen and one passing test, and check `apps/ios/scripts/test.sh` and the Build workflow pass.
   **Android:** `chore/android-project`: the Gradle scaffold from `apps/android/CLAUDE.md` (modules, wrapper, version catalog, `scripts/test.sh` and `scripts/build.sh`, the CI workflow), with an empty `core` and a placeholder screen. Its PR lists the baseline dependencies for the user to approve; don't merge it without that approval, even with `--merge`.
2. `feature/<app>-core`: the core logic (ported from the other app if it exists) with its tests (the app's engineer, then its test engineer, then `parity-reviewer` on the whole of `core` if the other app exists).
3. `feature/<app>-<screen>` and further layers, following the **Pending** rows in `docs/feature-parity.md`.

Each layer goes through steps 3–7 for that app only, and marks its rows **Done** in `docs/feature-parity.md`.

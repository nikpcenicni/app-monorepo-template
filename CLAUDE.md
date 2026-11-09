# __PROJECT_NAME__

__PROJECT_DESCRIPTION__ This is a monorepo: one app per folder under `apps/`, with the branching policy, versioning, CI and Claude config shared at the root. Layout is in [README.md](README.md#repository-layout).

| App | Folder | Status | Its rules |
| --- | --- | --- | --- |
| iOS and iPadOS (SwiftUI, iOS 17+) | `apps/ios/` | Not started. Rules for the first Xcode project are in its CLAUDE.md | [apps/ios/CLAUDE.md](apps/ios/CLAUDE.md) |
| Android (Kotlin, Jetpack Compose) | `apps/android/` | Not started. Same version as iOS | [apps/android/CLAUDE.md](apps/android/CLAUDE.md) |
| Website (home page: download links, contact, about) | `apps/web/` | Static landing page (HTML and CSS), not hosted yet. Own version | [apps/web/CLAUDE.md](apps/web/CLAUDE.md) |

Keep each app's code, scripts, docs and build output inside its own folder. Root `scripts/` is only for things every app shares (version, What to Test notes, branch policy, CI cleanup). Don't add an app's code to another app's folder, and don't share code between apps without asking: there is no shared package yet.

## Branching policy (always follow)

These rules decide the app's version, so breaking them gives a wrong version. Follow them in every session, local or in GitHub Actions, even for one-line changes.

1. **`main` only changes through pull requests.** Never commit or push to `main` directly. The `.githooks/pre-push` hook blocks it; don't bypass it with `--no-verify`.
2. **Every change starts on a branch from up-to-date `main`,** named `<type>/<short-kebab-slug>`:
   | Type | Use for | Version effect after the first release |
   | --- | --- | --- |
   | `feature/` | New behavior users can see | minor (1.1.0) |
   | `fix/` | Bug fixes | patch (1.0.1) |
   | `chore/`, `docs/`, `ci/`, `refactor/`, `test/` | Tooling, docs, CI, internal changes | patch, and only uploaded if app code changed |
   One branch, one kind of change. Don't mix a feature and unrelated fixes. Inside GitHub Actions, Claude's branch starts as `feature/…`; if the work is a fix or chore, push it to a correctly named branch and open the PR from that.
3. **Breaking changes** (for example saved data or settings that won't carry over) need `BREAKING CHANGE: <what>` in a commit message body. That makes the next version a major one.
4. **Merge PRs with a merge commit,** never squash or rebase. The merge commit keeps the branch name, which is how the version is worked out. Set the repo to allow merge commits only.
5. **Versions are never edited by hand.** `scripts/version.sh` works them out from git:
   - Marketing version stays **1.0** until the first store release is tagged `v1.0.0`. Until then, every change ships as 1.0 with a higher build number.
   - After that, it's the last `vX.Y.Z` tag, raised by the largest change merged since (major > minor > patch).
   - Build number = first-parent commits on `main` (+ `BUILD_OFFSET` in `scripts/_common.sh`), so every merge raises it.
   - `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` stay at 1.0 and 1 as placeholders, as do `versionName` and `versionCode` defaults in Gradle. Don't change them.
6. **Store test uploads come only from `main`.** Merging a PR that changes iOS app code (`apps/ios/__APP_TARGET__/`, the Xcode project, entitlements or `__APP_TARGET__-Info.plist`) triggers the TestFlight workflow, which tags the upload `build/<N>`. `apps/ios/scripts/testflight.sh` refuses any other branch, a dirty tree, or a `main` that differs from `origin/main`.
7. **Dependent work is stacked, not piled up.** When a change builds on a branch that hasn't merged yet, use GitHub's stacked PRs (`gh stack`) instead of branching from `main` and waiting, or putting both changes in one branch. Each layer is its own policy-named branch and PR (types can differ: a `fix/` can sit on a `feature/`), the bottom PR targets `main`, and each PR above targets the branch below it. Keep a stack's history linear: update it with `gh stack sync` or `gh stack rebase`, never by merging `main` into a stack branch. Merge a stack one layer at a time, bottom first: `gh stack merge <bottom-pr> --merge -y`, then the next PR once it has retargeted to `main` and its checks pass. Merging several layers in one `gh stack merge` call lands them in a single merge commit named after the top branch, so `scripts/version.sh` never sees the lower branches' types.
8. **Parallel agents each work in their own git worktree** (the `EnterWorktree` tool, `isolation: "worktree"`, or `git worktree add`), never in a checkout another agent is using. Independent changes get separate branches from `main`. Only stack changes that really depend on each other. If `gh stack` exits 8 (stack locked), another agent is updating that stack: wait and retry, don't force it.
9. **Store releases are tagged** `vX.Y.Z` (annotated) on the exact `main` commit that was submitted, only once the user confirms that build was submitted. Never create or move a `v*` tag without the user saying so.

Check the version a branch would produce with `scripts/version.sh explain`.

**The iOS and Android apps always share one version.** `scripts/version.sh` gives both the same marketing version and build number (on Android, `versionName` and `versionCode`), and one `vX.Y.Z` tag marks a release of both. Changes to either app, or to shared files, count towards it.

**The website (`apps/web/`) is versioned on its own.** It is the apps' home page (download links, contact, about), so its version stays mostly fixed and is set in `apps/web/package.json`, not by `scripts/version.sh`. Branches and merges that only change `apps/web/` are left out of the app version and out of TestFlight's What to Test notes (`counts_for_app_version` in `scripts/_common.sh`). They still add a commit to `main`, so the build number goes up, which is harmless. The branching policy (branch names, PRs, merge commits) applies to website changes as to everything else. Don't create `v*` tags for the website.

## Commands

| Task | Command |
| --- | --- |
| Build and run iOS unit tests (simulator) | `apps/ios/scripts/test.sh` |
| Build and run Android unit tests and lint (once scaffolded) | `apps/android/scripts/test.sh` |
| Current version, and why | `scripts/version.sh`, `scripts/version.sh explain` |
| Upload `main` to TestFlight by hand (CI does this on merge) | `apps/ios/scripts/testflight.sh --tag` |
| Print the What to Test notes for the next build | `scripts/what-to-test.sh` |
| Set a build's What to Test by hand (needs the App Store Connect API key) | `swift apps/ios/scripts/set-testflight-notes.swift <notes file> <marketing version> <build>` |
| Start a stack, add a layer, open its PRs | `gh stack init <branch>`, `gh stack add <branch>`, `gh stack submit --auto --open` |
| Bring a stack up to date with `main` | `gh stack sync --accept-base-change` |
| Check release signing without uploading (any branch) | `apps/ios/scripts/testflight.sh --archive-only --skip-tests` |

Run scripts from anywhere; they find their own folders. The iOS scripts find Xcode on their own even when `xcode-select` points at the Command Line Tools, and write to `apps/ios/build/` (logs in `apps/ios/build/logs/`). After cloning, run `git config core.hooksPath .githooks` once, and `gh extension install github/gh-stack` for stacked PRs.

## Workflow

- `/ship <feature>` takes a request from branch through implementation, review and PR, and can merge it so CI uploads to TestFlight. By default a user-visible feature or fix is built on **both iOS and Android** in one PR: one shared spec, each app's specialist agents running in parallel in their own worktrees, and `parity-reviewer` checking the apps still match. `--ios-only`, `--android-only` and `--web` narrow it. `/testflight` uploads `main` by hand.
- [docs/feature-parity.md](docs/feature-parity.md) lists every user-visible feature and its status on iOS and Android. Keep it current: a feature built on one app only is **Pending** on the other.
- Specialist agents are in `.claude/agents/`:
  | Area | iOS | Android | Website |
  | --- | --- | --- | --- |
  | Implement | `swift-engineer` | `kotlin-engineer` | `web-engineer` |
  | Game services (games only; delete if unused) | `gamekit-specialist` | `play-games-specialist` | |
  | Tests | `test-engineer` | `android-test-engineer` | |
  | Design review | `swiftui-design-reviewer` | `compose-design-reviewer` | |
  | Store compliance | `app-store-compliance` | `play-store-compliance` | |
  | Build and signing | `build-doctor` | `android-build-doctor` | |

  Shared by all apps: `accessibility-auditor` (iOS, Android and web), `parity-reviewer` (iOS against Android), `docs-keeper`, `release-manager`.
- Each agent's `model` is set by how much the work needs judgment. Keep to these tiers when adding or editing agents, and only change them on purpose:
  | Model | Agents | Why |
  | --- | --- | --- |
  | `opus` | `test-engineer`, `android-test-engineer`, `swiftui-design-reviewer`, `compose-design-reviewer`, `accessibility-auditor`, `parity-reviewer`, `app-store-compliance`, `play-store-compliance`, and the `Plan` step in `/ship` | Planning, test design and reviews, where a missed issue costs most |
  | `sonnet` | `swift-engineer`, `kotlin-engineer`, `web-engineer`, `gamekit-specialist`, `play-games-specialist`, `build-doctor`, `android-build-doctor` | Implementing from a plan and fixing builds |
  | `haiku` | `docs-keeper`, `release-manager` | Mechanical work: syncing docs, running release scripts, writing notes |
- **Every PR description has a `## What to Test` section**: 2–5 plain-text bullets for testers, or `- Nothing new to test.` The TestFlight workflow copies the sections of the PRs in each build into its TestFlight What to Test text (`scripts/what-to-test.sh`, set by `apps/ios/scripts/set-testflight-notes.swift` when the App Store Connect API key secrets exist). This applies in GitHub Actions too.
- **Docs stay in step with the code.** Before opening any PR, run the `docs-keeper` agent on the branch so the App Store listing (`apps/ios/docs/app-store-submission.md`), the Play Store listing (`apps/android/docs/play-store-listing.md`), `docs/feature-parity.md`, the root and per-app READMEs and other docs match the change, and commit its edits on the same branch. This applies in GitHub Actions too.

## Code rules (all apps)

- Don't add package dependencies without asking.
- Commit messages: imperative, sentence case, no prefix (e.g. "Add a pause button to the timer").
- App-specific rules live in that app's `CLAUDE.md` ([apps/ios/CLAUDE.md](apps/ios/CLAUDE.md), [apps/android/CLAUDE.md](apps/android/CLAUDE.md), [apps/web/CLAUDE.md](apps/web/CLAUDE.md)). Follow them for any change in that folder.
- iOS and Android are the same product: rules, numbers, settings and wording match. Whichever app is built first is the reference for anything built before the other exists; [docs/feature-parity.md](docs/feature-parity.md) says which.

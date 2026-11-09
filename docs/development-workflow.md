# Development workflow

How to go from an idea to a TestFlight build with Claude, from a computer or a phone.

## Three ways to start

| Where you are | How | What happens |
| --- | --- | --- |
| At the Mac | `claude`, then `/ship Add a pause button to the timer` (add `--merge` to merge once checks pass) | Claude builds the feature on a `feature/` branch, tests it, runs the accessibility and design reviews and opens a PR. Merging it triggers the TestFlight upload. |
| Phone, Mac at home | Run `/remote-control` in a Claude Code session in this folder, then open that session in the Claude app on your phone and send `/ship …` | Same as above, running on your Mac. |
| Phone, nothing running | Open a GitHub issue or comment: `@claude /ship Add a pause button to the timer` | Claude runs on the self-hosted Mac, builds and tests, and opens a PR. Merge the PR in the GitHub app, and the **TestFlight** workflow uploads the build. |

Upload `main` again without new code: `/testflight`, or **Actions → TestFlight → Run workflow** in the GitHub app.

## Planning and the roadmap

Decide what to build before building it:

1. **Discuss it.** Ask Claude to "use the product-planner to plan the app" (or "…to work out how X should work"). It asks a few questions at a time, each with options and a recommendation, and you answer in one line ("1a, 2 as recommended"). For a longer back-and-forth, run it as the session's main agent: `claude --agent product-planner`.
2. **Record it.** Once you agree, it writes the decisions to [product.md](product.md) (pitch, audience, scope for 1.0, screens, decision log) and adds items to [roadmap.md](roadmap.md), each sized to one PR with acceptance cases.
3. **Build it.** `/ship R-003` builds one item; `/ship next` builds the highest-priority item that isn't blocked or already in a PR. The item's acceptance cases become test cases in the shared spec, and the item moves to **Done** in the same PR. From a phone: `@claude /ship next` on an issue.

Commit the planner's edits on a `docs/` branch and open a PR like any other change (`- Nothing new to test.`).

## Pipeline

`/ship` builds a user-visible feature or fix on **iOS and Android together** by default, in one branch and one PR (`--ios-only`, `--android-only` or `--web` narrow it). Until an app has code, it builds the other one only and marks the feature **Pending** for it in [feature-parity.md](feature-parity.md).

```
request ─► Plan (opus): one shared spec (rules, numbers, strings, test cases) + a plan per app
        ─► in parallel, each in its own git worktree:
             iOS:     swift-engineer / gamekit-specialist (games) ─► apps/ios/scripts/test.sh
             Android: kotlin-engineer / play-games-specialist (games) ─► apps/android/scripts/test.sh
        ─► commits brought onto the feature branch
        ─► test-engineer (iOS) and android-test-engineer (Android): every spec test case on both
        ─► in parallel, findings only:
             accessibility-auditor (each platform that changed)
             swiftui-design-reviewer / compose-design-reviewer
             parity-reviewer (iOS and Android still match)
             app-store-compliance / play-store-compliance (only when data, purchases or services change)
        ─► fixes applied, tests re-run
        ─► docs-keeper (always: store listings, feature parity, READMEs, docs; web-engineer if the site copy is stale)
        ─► commit, PR ─► merge to main ─► TestFlight workflow on the self-hosted Mac
                                           (version from git, archive, upload, tag build/N)
```

Website changes (`--web`) go through `web-engineer`, `accessibility-auditor` and `docs-keeper`, and nothing uploads.

## Agents

| Agent | Role | Edits code |
| --- | --- | --- |
| `product-planner` | Discusses design options and recommends; keeps the product brief and roadmap that `/ship` builds from | Yes (`docs/product.md`, `docs/roadmap.md` only) |
| `swift-engineer` | Implements iOS features and fixes in Swift and SwiftUI | Yes |
| `kotlin-engineer` | Implements Android features and fixes in Kotlin and Jetpack Compose, and ports logic from iOS | Yes |
| `web-engineer` | The static home page in `apps/web/` | Yes |
| `gamekit-specialist` | Game Center (games only): leaderboards, achievements, challenges, keeping IDs in sync | Yes |
| `play-games-specialist` | Play Games Services (games only): leaderboards and achievements, mapped to the Game Center IDs | Yes |
| `test-engineer` | XCTest for the iOS Core logic, diagnosing failing tests | Yes (tests) |
| `android-test-engineer` | JUnit for the Android core module, mirroring the iOS tests case for case | Yes (tests) |
| `accessibility-auditor` | VoiceOver, TalkBack, switch access, text size, reduced motion, contrast, gesture alternatives; WCAG for the website | Yes, unless asked for audit only |
| `swiftui-design-reviewer` | Human Interface Guidelines, layout on all Apple devices, SwiftUI state and performance | No |
| `compose-design-reviewer` | Material 3 and Android conventions, layout on phones, tablets and foldables, Compose state and recomposition | No |
| `parity-reviewer` | Checks iOS and Android still behave the same: rules, numbers, strings, settings, tests | No |
| `app-store-compliance` | App Store Review Guidelines, privacy manifest, export compliance, metadata | No |
| `play-store-compliance` | Google Play policies, target API level, permissions, Data safety, listing limits | No |
| `docs-keeper` | Keeps the store listings, feature parity, READMEs, docs, CLAUDE.md and agent files in step with the code. Runs on every branch before its PR | Yes (docs only) |
| `build-doctor` | xcodebuild, signing, provisioning and upload errors | Yes (config) |
| `android-build-doctor` | Gradle, Android SDK, JDK, lint, signing and Play upload errors | Yes (config) |
| `release-manager` | TestFlight (and later Play) uploads from main, release tags, What to Test notes | No (runs scripts) |

You can also call any agent directly, for example: "use the accessibility-auditor to audit the whole app, audit only".

## Branching and versioning

The full policy is in [CLAUDE.md](../CLAUDE.md#branching-policy-always-follow). In short:

- Work happens on `feature/…`, `fix/…`, `chore/…`, `docs/…`, `ci/…`, `refactor/…` or `test/…` branches, and reaches `main` only through a PR merged with a merge commit.
- Work that depends on an unmerged branch is stacked with GitHub's stacked PRs (`gh stack`): each layer is its own policy-named branch and PR, the bottom one targets `main` and each one above targets the branch below. Keep a stack up to date with `gh stack sync` (never merge `main` into it) and land it one layer at a time from the bottom (`gh stack merge <bottom-pr> --merge`), so each PR gets its own merge commit. Merging several layers in one call produces a single merge commit named after the top branch, and `scripts/version.sh` then can't see the lower branches' types.
- Agents working in parallel each use their own git worktree. Independent changes branch from `main`; only dependent ones are stacked.
- `scripts/version.sh` works the version out from git. iOS and Android share it; branches that only change the website (`apps/web/`) don't count, since the site has its own version. Nothing is bumped by hand, and the numbers in `project.pbxproj` are placeholders.
- **Until the first App Store release, the version stays 1.0.** Each build on `main` gets a higher build number: 1.0 (7), 1.0 (8) and so on.
- When you submit a build for review, tag that commit `v1.0.0` (or ask Claude to). After that, merges set the next version: a `feature/` branch gives 1.1.0, a `fix/` gives 1.0.1, and `BREAKING CHANGE:` in a commit gives 2.0.0.
- The build number is the number of first-parent commits on `main`, so every merge raises it. Each TestFlight upload is tagged `build/<N>`.
- `scripts/version.sh explain` shows the version and the reasons for it. On a stacked branch it also counts the unmerged branches below it, since they land together. The **Branch policy** check on each PR shows the version that merge will produce.

Enforcement, since GitHub Free doesn't offer branch protection on private repos:
- **Local:** the `.githooks/pre-push` hook blocks pushes to `main` and badly named branches. Enable it once per clone with `git config core.hooksPath .githooks`.
- **On GitHub:** the **Branch policy** check fails PRs from badly named branches, or that target anything but `main` or a policy-named branch below them in a stack (it warns if such a PR isn't linked into a stack yet). The repo only allows merge commits and deletes branches after merging.
- **Scripts and Claude:** `apps/ios/scripts/testflight.sh` only uploads a clean `main` that matches `origin/main`. Every Claude session loads the policy from CLAUDE.md.

## One-time setup

**Local (Mac)**
1. Xcode → Settings → Accounts: be signed in with the Apple ID for team __APPLE_TEAM_ID__. Create or import an Apple Distribution certificate under Manage Certificates.
2. Optional: `sudo xcode-select -s /Applications/Xcode.app` so plain `xcodebuild` works too. The scripts work without it.
3. For stacked PRs: `gh extension install github/gh-stack`. The `claude.yml` workflow installs it on the runner itself.
4. The app record for `__BUNDLE_ID__` must exist in App Store Connect before the first upload (see [app-store-submission.md](../apps/ios/docs/app-store-submission.md)).

**GitHub: remote Claude**
1. In Claude Code, run `/install-github-app` and choose this repo. Or install the Claude GitHub app and add the secret by hand.
2. Run `claude setup-token` and save the result as the repo secret `CLAUDE_CODE_OAUTH_TOKEN`.
3. Only the repo owner's comments trigger Claude.

**GitHub: the self-hosted Mac**

The TestFlight workflow runs on a self-hosted runner labeled `__PROJECT_SLUG__-release`, so builds are signed with your own certificate and Apple ID, and no App Store Connect key is needed to upload. (The optional API key secrets below only add the What to Test notes, or replace the Apple ID if it stops working.) On that Mac:
1. Install Xcode, open it once to accept the license, and install an iOS simulator runtime (the workflow runs the unit tests first).
2. Xcode → Settings → Accounts: sign in with the Apple ID for team __APPLE_TEAM_ID__. Under Manage Certificates, make sure an Apple Distribution certificate is present. Create one there, or import it from another Mac.
3. Install the runner as a service (`./svc.sh install && ./svc.sh start` in the runner folder). It runs as a LaunchAgent for your user.
4. Turn on automatic login for that user and turn off sleep. Signing needs the login keychain, which is only unlocked while the user is logged in.
5. The workflow pushes a `build/<N>` tag after each upload. It never pushes commits.

Every workflow runs on this Mac (labels `self-hosted, macOS`), so its Xcode is the one CI builds with and no job uses GitHub-hosted minutes. Only `testflight.yml` signs and uploads. `claude.yml` also runs Claude here (when someone mentions `@claude`), as your user, on the machine with your signing certificate and Apple ID. Anyone who can comment `@claude` on an issue or PR can steer it, and the code in every PR builds and runs its tests here, so keep the repo private and its collaborators trusted. The runner takes one job at a time, so a long Claude session holds up builds until it finishes.

If uploads with the Xcode Apple ID stop working, add an App Store Connect API key with the **App Manager** role as the repo secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8_BASE64` (`base64 -i AuthKey_XXXX.p8 | pbcopy`). The workflow uses it when present. Signing still uses the local certificate, so it doesn't need Admin. The same key lets the workflow set each build's What to Test notes in TestFlight (`apps/ios/scripts/set-testflight-notes.swift`). Without it, the notes are listed in the run summary, to paste into App Store Connect → TestFlight → the build → Test Details.

The scripts use the Xcode that `xcode-select` points at on the runner, or the newest one in `/Applications` if that isn't a full Xcode. After upgrading Xcode on the runner, run `sudo xcode-select -s /Applications/Xcode.app`. The runner also needs an iOS Simulator runtime installed (Xcode → Settings → Components).

What runs when, so nothing is built twice:

| Event | Runs |
| --- | --- |
| Pull request | iOS unit tests (only when `apps/ios/` (apart from its docs and Markdown), `scripts/` or the Build workflow changed; skipped until the Xcode project exists), branch-name check, Claude review |
| Merge to `main` that changes app code | TestFlight: tests, archive, upload, What to Test notes from the PRs merged since the last build |
| Merge to `main` that doesn't | Nothing |
| `v*` tag | Unsigned IPA attached to the GitHub release |
| Build, run by hand | Unit tests and unsigned IPA |

Every job that builds ends with `scripts/ci-cleanup.sh` (even when the job fails). It removes `build/` and `dist/` at the repo root and in each app under `apps/`, and this project's folders in `~/Library/Developer/Xcode/DerivedData`. Upload any artifacts before that step. Simulators are left alone so the next job can reuse them.

If you reinstall the runner service, remove `SessionCreate` from its LaunchAgent plist (`/usr/libexec/PlistBuddy -c "Delete :SessionCreate" ~/Library/LaunchAgents/actions.runner.*.plist`, then `./svc.sh stop && ./svc.sh start`). With it, the runner gets its own security session where the login keychain stays locked, and signing fails with `errSecInternalComponent`.

The workflows assume one self-hosted Mac. To use GitHub-hosted runners instead, change `runs-on` to `macos-latest` (or `ubuntu-latest` for jobs that don't need Xcode), drop the `scripts/ci-cleanup.sh` steps, and give the TestFlight job signing through an App Store Connect API key and a distribution certificate in secrets.

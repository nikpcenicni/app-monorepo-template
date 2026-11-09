# Using this template

A monorepo starter for an app shipped on iOS, Android and a static website, with the Claude Code setup that builds features on both apps at once: 18 specialist agents, the `/ship` and `/testflight` skills, a branching policy that works out versions from git, and CI for branch checks, iOS tests, TestFlight uploads and `@claude` on issues.

It was taken from a shipping project and made generic. Nothing app-specific is left: the iOS and Android folders hold only rules, scripts and store-listing skeletons, ready for the first project to be created.

This file and `scripts/init-template.sh` delete themselves when you initialise a project.

## Start a project

```sh
cp -R app-monorepo-template my-app && cd my-app     # or "Use this template" on GitHub
rm -rf .git && git init -b main
scripts/init-template.sh                            # asks for each value
```

Or pass everything at once:

```sh
scripts/init-template.sh --name "Acme Notes" --description "A calm notes app." \
  --bundle-id dev.example.acmenotes --team-id ABCDE12345 \
  --owner "Example Ltd" --owner-url https://example.com --no-game-services --yes
```

Then commit, push to a new GitHub repo, and set it to allow merge commits only.

## Placeholders

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `__PROJECT_NAME__` | Display name | Acme Notes |
| `__PROJECT_SLUG__` | Lowercase with hyphens: runner label `<slug>-release`, web package name | acme-notes |
| `__APP_TARGET__` | Xcode project, scheme and folder name | AcmeNotes |
| `__PROJECT_DESCRIPTION__` | One sentence, used in READMEs, CLAUDE.md, agents and the website | A calm notes app. |
| `__BUNDLE_ID__` | iOS bundle ID and Android application ID | dev.example.acmenotes |
| `__APPLE_TEAM_ID__` | Apple Developer team ID (can be left for later) | ABCDE12345 |
| `__OWNER_NAME__`, `__OWNER_URL__` | Website footer credit | Example Ltd, https://example.com |
| `__YEAR__` | Website footer year | set to this year |

Comments like `<!-- … -->` and **Open question:** markers in docs are for you to fill in as the project takes shape.

## What's included

| Path | What |
| --- | --- |
| `CLAUDE.md`, `apps/*/CLAUDE.md` | Repo-wide branching policy, versioning, workflow and agent tiers; per-app code rules |
| `.claude/agents/` | `product-planner`, `swift-engineer`, `kotlin-engineer`, `web-engineer`, `test-engineer`, `android-test-engineer`, `swiftui-design-reviewer`, `compose-design-reviewer`, `accessibility-auditor`, `parity-reviewer`, `app-store-compliance`, `play-store-compliance`, `build-doctor`, `android-build-doctor`, `docs-keeper`, `release-manager`, and for games `gamekit-specialist` and `play-games-specialist` |
| `.claude/skills/` | `/ship` (spec → parallel iOS and Android builds in worktrees → tests → reviews → docs → PR → merge) and `/testflight` |
| `scripts/` | `version.sh` (version from git), `what-to-test.sh` (TestFlight notes from PRs), `ci-cleanup.sh`, `_common.sh` |
| `apps/ios/scripts/` | `test.sh`, `testflight.sh`, `set-testflight-notes.swift`, `_common.sh` |
| `.github/workflows/` | Branch policy check, iOS build and tests, TestFlight on merge, Claude on `@claude` |
| `.githooks/pre-push` | Blocks pushes to `main` and badly named branches |
| `docs/` | Development workflow and setup, product brief, roadmap, feature parity table |
| `apps/*/docs/` | App Store and Play Store listing skeletons |
| `apps/web/` | A static landing page with "Coming soon" store buttons |

## Assumptions to check

- **CI runs on one self-hosted Mac** (labels `self-hosted, macOS`, plus `<slug>-release` for TestFlight). To use GitHub-hosted runners, see the end of [docs/development-workflow.md](docs/development-workflow.md).
- **The iOS Xcode project is created by hand** in Xcode with the names in [apps/ios/CLAUDE.md](apps/ios/CLAUDE.md#creating-the-xcode-project). Until it exists, the iOS workflows skip their work.
- **The Android Gradle project** is scaffolded by `kotlin-engineer` when you run `/ship Start the Android app`.
- **Only some apps?** Delete the app's folder, its agents, and its rows in `CLAUDE.md`, the `/ship` skill and `docs/development-workflow.md`. For an iOS-only project also delete `parity-reviewer` and `docs/feature-parity.md`.

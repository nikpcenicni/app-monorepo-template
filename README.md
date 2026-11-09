# __PROJECT_NAME__

__PROJECT_DESCRIPTION__

This repository holds every version of the app: one app per folder under `apps/`, sharing the branching policy, versioning, CI and Claude Code setup at the root.

| App | Folder | Status |
| --- | --- | --- |
| iPhone and iPad | [apps/ios](apps/ios/README.md) | Not started |
| Android | [apps/android](apps/android/README.md) | Not started |
| Website: home page with download links, contact and about | [apps/web](apps/web/README.md) | Static landing page, not hosted yet. Store links show "Coming soon" until the apps are live |

## Repository layout

```
apps/
  ios/                     iOS and iPadOS app (CLAUDE.md has the project layout to create)
    scripts/               Test, TestFlight and What to Test scripts
    docs/                  App Store listing
  android/                 Android app (CLAUDE.md has its planned stack and rules)
    docs/                  Play Store listing
  web/                     Website: static landing page (index.html, styles.css, assets/)
scripts/                   Shared by every app: version.sh, what-to-test.sh, ci-cleanup.sh, _common.sh
docs/                      Shared docs: development-workflow.md, product.md (brief and decisions), roadmap.md (what to build next), feature-parity.md (what each app has)
.github/workflows/         CI: branch policy, iOS build and tests, TestFlight, Claude
.githooks/                 pre-push hook that enforces the branching policy
.claude/                   Claude Code agents (per platform and shared) and skills (/ship, /testflight)
CLAUDE.md                  Repo-wide rules: branching policy, versioning, workflow
```

Each app keeps its code, scripts, docs and build output inside its own folder. Root `scripts/` and `docs/` are only for things every app shares.

## Getting started

After cloning:

```sh
git config core.hooksPath .githooks       # enforce the branching policy on push
gh extension install github/gh-stack      # stacked pull requests
```

Then follow the README of the app you're working on, or start one with Claude Code: `/ship Start the iOS app`.

## Branches, versions and releases

Every change goes through a pull request from a `feature/`, `fix/`, `chore/`, `docs/`, `ci/`, `refactor/` or `test/` branch, merged with a merge commit. The iOS and Android apps always share one version, worked out from git by `scripts/version.sh`; nothing is bumped by hand. The website has its own version, and changes that only touch it don't move the apps'. Merging a PR that changes the iOS app uploads a TestFlight build. The full rules are in [CLAUDE.md](CLAUDE.md#branching-policy-always-follow), and the day-to-day workflow, including running it from a phone with Claude Code, is in [docs/development-workflow.md](docs/development-workflow.md).

CI only builds what changed: iOS tests run on pull requests that touch `apps/ios/` or the shared `scripts/`, and Android and website changes won't trigger them.

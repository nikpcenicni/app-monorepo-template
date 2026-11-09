# __PROJECT_NAME__ for iOS

Placeholder. The iPhone and iPad version of __PROJECT_NAME__ will live in this folder: SwiftUI, iOS 17+, no third-party dependencies.

This is the iOS app in the [__PROJECT_NAME__ monorepo](../../README.md). Paths in this README are relative to `apps/ios/` unless they say otherwise.

## Starting the app

Create the Xcode project with the names in [CLAUDE.md](CLAUDE.md#creating-the-xcode-project), so the scripts and CI find it, then run `/ship Start the iOS app` in Claude Code. Until the project exists, the Build workflow skips its tests and the TestFlight workflow has nothing to upload.

## Commands

| Task | Command |
| --- | --- |
| Build and run the unit tests in the simulator | `scripts/test.sh ["iPhone 16 Pro"]` |
| Archive and upload `main` to TestFlight (CI does this on merge) | `scripts/testflight.sh --tag` |
| Check release signing without uploading | `scripts/testflight.sh --archive-only --skip-tests` |
| Set a build's What to Test notes | `swift scripts/set-testflight-notes.swift <notes file> <marketing version> <build>` |

Output goes to `build/`, logs to `build/logs/`. The version comes from `../../scripts/version.sh`; nothing is bumped by hand.

## Claude agents

`swift-engineer` builds features, `test-engineer` writes the XCTest tests, `swiftui-design-reviewer` and `accessibility-auditor` review the UI, `gamekit-specialist` handles Game Center (games only), `app-store-compliance` checks App Store rules, and `build-doctor` fixes Xcode, signing and upload problems. `/ship` runs them alongside the Android agents so a feature lands on both apps in one PR.

<!-- Once the app has code, add: features, how it works, accessibility, code layout (every file with a one-line purpose). docs-keeper keeps them current. -->

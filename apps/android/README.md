# __PROJECT_NAME__ for Android

Placeholder. The Android version of __PROJECT_NAME__ will live in this folder. There is no code yet.

The code rules, stack (Kotlin and Jetpack Compose) and module layout the app will use are in [CLAUDE.md](CLAUDE.md). In short:

- Keep everything Android in this folder: the Gradle project, its scripts (`apps/android/scripts/`), its docs (`apps/android/docs/`, including the Play Store listing) and its build output.
- [docs/feature-parity.md](../../docs/feature-parity.md) lists which features each app has, and which app is the reference for rules not built here yet.
- Add a CI workflow that only runs on changes under `apps/android/`, the way `.github/workflows/build.yml` does for iOS.
- Android always has the same version as iOS (see the root [CLAUDE.md](../../CLAUDE.md#branching-policy-always-follow)). Take `versionName` from `scripts/version.sh marketing` and `versionCode` from `scripts/version.sh build` at build time, the way `apps/ios/scripts/testflight.sh` passes them to Xcode; don't write them into `build.gradle(.kts)` by hand. A release is one `vX.Y.Z` tag for both apps.

## Claude agents

`kotlin-engineer` builds features, `android-test-engineer` writes the JUnit tests, `compose-design-reviewer` and `accessibility-auditor` review the UI, `play-games-specialist` handles Play Games Services (games only), `play-store-compliance` checks Google Play policy, and `android-build-doctor` fixes Gradle, SDK and signing problems. `/ship` runs them alongside the iOS agents so a feature lands on both apps in one PR, and `parity-reviewer` checks the two match.

To start the app, run `/ship Start the Android app`.

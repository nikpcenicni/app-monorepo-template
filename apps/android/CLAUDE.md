# __PROJECT_NAME__ for Android

The Android app. **There is no code yet**: these are the rules the first Gradle project and everything after it must follow. The branching policy, versioning and workflow in the [root CLAUDE.md](../../CLAUDE.md) apply here too. Paths below are relative to `apps/android/`.

The Android app is the same product as the iOS app. Its rules, numbers, settings and wording match [apps/ios](../ios/), and new features land on both apps in the same PR (see `/ship`). What each app has is tracked in [docs/feature-parity.md](../../docs/feature-parity.md) at the repo root.

## Stack

- Kotlin, Jetpack Compose with Material 3, a single `Activity`. Gradle with the Kotlin DSL (`*.gradle.kts`) and a version catalog (`gradle/libs.versions.toml`), plus the Gradle wrapper checked in.
- `minSdk` 26, `targetSdk` and `compileSdk` at the level Google Play currently requires. JDK 17.
- Application ID `__BUNDLE_ID__`, matching the iOS bundle ID.
- Phones, tablets, foldables and ChromeOS windows, every orientation, with edge-to-edge drawing.

## Modules

| Module | Holds | Mirrors |
| --- | --- | --- |
| `core/` | Pure Kotlin (JVM library): rules, models, anything testable without UI. No `android.*`, `androidx.*` or Compose imports | `../ios/__APP_TARGET__/Core/` |
| `core/src/test/` | JUnit tests for `core` | `../ios/__APP_TARGET__Tests/` |
| `app/` | Compose UI, theming, haptics, persistence, platform services | `../ios/__APP_TARGET__/Views/` and `Support/` |

## Code rules

- Logic goes in `core/`, with tests. When porting from Swift, keep the same type names where Kotlin allows, so the two can be compared side by side. When a rule is unclear, the reference app's code and tests decide (see [docs/feature-parity.md](../../docs/feature-parity.md)).
- `core` tests match the iOS tests case for case: same inputs, same expected values. A rule that's tested on iOS is tested here.
- Randomness takes an injected `kotlin.random.Random`; time takes an injected clock.
- Layout adapts to the window's actual size, not `WindowSizeClass` breakpoints or the display size alone.
- Persisted state uses `SharedPreferences` (or DataStore) with the same key names as the iOS `UserDefaults` keys.
- User-facing text lives in `app/src/main/res/values/strings.xml`, uses the same wording as iOS, and uses plurals and placeholders rather than joined strings.
- New UI needs TalkBack labels (`contentDescription`, `semantics`), a non-drag alternative for any drag interaction, touch targets of at least 48 dp, text in `sp` that survives a 200% font scale, and no motion when the system's **Remove animations** setting is on.
- Haptics go through one helper and respect the system's touch-feedback setting.

## Dependencies

Don't add dependencies without asking (root rule). The first scaffold needs the user's OK for its baseline set, proposed in the PR: Kotlin stdlib, AndroidX Core, Activity Compose, Lifecycle, the Compose BOM with Material 3, and JUnit and Compose UI Test for tests. No analytics, ads or crash-reporting SDKs without the user asking.

## Scripts and versions

Scripts live in `scripts/`, run from anywhere and write to `build/` (logs in `build/logs/`), like the iOS ones. They source the repo-wide `../../scripts/_common.sh`. The first scaffold adds:

| Script | Does |
| --- | --- |
| `scripts/test.sh` | `./gradlew :core:test :app:testDebugUnitTest :app:lintDebug`, log in `build/logs/test.log` |
| `scripts/build.sh` | Debug APK, or a signed release bundle with `--release` |

- `versionName` comes from `scripts/version.sh marketing` and `versionCode` from `scripts/version.sh build`, passed to Gradle as `-PversionName=… -PversionCode=…`. Never write them into `build.gradle.kts`; the defaults there are placeholders (`1.0`, `1`).
- A CI workflow `.github/workflows/android.yml` runs `scripts/test.sh` on pull requests that change `apps/android/`, on the self-hosted runner, and ends with `scripts/ci-cleanup.sh`.
- Uploads to Google Play (internal testing) come only from `main`, like TestFlight. There's no upload workflow yet.
- Release signing uses an upload keystore that is never committed (`~/.gradle/gradle.properties` locally, repo secrets in CI).

## Docs

`docs/play-store-listing.md` is the Play Store listing (title 30 characters, short description 80, full description 4,000), the Data safety answers and the content rating. The `docs-keeper` agent keeps it in step.

<!-- Add project-specific rules below as the app grows. -->

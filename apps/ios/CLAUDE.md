# __PROJECT_NAME__ for iOS

The iOS and iPadOS app: SwiftUI, iOS 17+, no third-party dependencies. Bundle ID `__BUNDLE_ID__`, team `__APPLE_TEAM_ID__`. The branching policy, versioning and workflow in the [root CLAUDE.md](../../CLAUDE.md) apply here too.

Paths below are relative to `apps/ios/`. Scripts can be run from anywhere, for example `apps/ios/scripts/test.sh` from the repo root.

## Creating the Xcode project

**There is no Xcode project yet.** The scripts and CI expect this layout, so create it with exactly these names (Xcode → File → New → Project → App, SwiftUI, Swift Testing or XCTest, save into `apps/ios/`):

| Item | Name |
| --- | --- |
| Project and scheme | `__APP_TARGET__.xcodeproj`, scheme `__APP_TARGET__` (shared, so it's committed under `xcshareddata/`) |
| App code | `__APP_TARGET__/` (a synchronized folder, objectVersion 77) |
| Unit tests | `__APP_TARGET__Tests/` |
| Bundle ID and team | `__BUNDLE_ID__`, `__APPLE_TEAM_ID__`, automatic signing |
| Info.plist | `GENERATE_INFOPLIST_FILE = YES`; keys with no build setting go in `__APP_TARGET__-Info.plist` next to the project |
| Entitlements | `__APP_TARGET__.entitlements` next to the project, if any |
| Privacy manifest | `__APP_TARGET__/PrivacyInfo.xcprivacy` |
| Export compliance | `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` unless the app uses non-exempt encryption |

Leave `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 1`: the scripts pass the real values from `scripts/version.sh`.

## Code rules

- `__APP_TARGET__/Core/` is pure Swift: no SwiftUI, UIKit or other UI framework imports. Rules, models and anything testable without UI go here, with tests in `__APP_TARGET__Tests/`.
- `__APP_TARGET__/Views/` is SwiftUI. `__APP_TARGET__/Support/` holds platform glue (persistence, haptics, theming, services).
- The project uses synchronized folders: new files in `__APP_TARGET__/` or `__APP_TARGET__Tests/` join their target automatically. Don't edit `project.pbxproj` to add files.
- Randomness and time in `Core/` are injected (a `RandomNumberGenerator`, a clock) so tests are deterministic.
- New UI needs accessibility labels, a non-drag alternative for any drag interaction, Dynamic Type support, and must respect Reduce Motion.
- Layout adapts to the window's actual size (iPhone, iPad full screen, Split View, Stage Manager), not to size classes or `UIScreen` alone.
- Info.plist keys go in `INFOPLIST_KEY_*` build settings. Keys with no such setting go in `__APP_TARGET__-Info.plist` at the root of `apps/ios`. Don't put a plist in `__APP_TARGET__/`: the synchronized folder would also copy it into the app as a resource.
- A new required-reason API (UserDefaults, file timestamps, disk space, boot time) must be declared in `__APP_TARGET__/PrivacyInfo.xcprivacy`.
- A user-visible feature added here is **Pending** for Android in [docs/feature-parity.md](../../docs/feature-parity.md) until it's built there. Features that can't exist on Android are marked **iOS only**.

<!-- Add project-specific rules below as the app grows: architecture decisions, crash workarounds, naming. -->

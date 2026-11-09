# Feature parity

__PROJECT_NAME__ is one product on iOS and Android. This table lists every user-visible feature and where each app stands, so a feature built on one app isn't forgotten on the other. `/ship` builds new features on both apps in one PR; this file is for the gaps: features built before the second app existed, and anything that could only be built on one app.

Status: **Done**, **Pending** (should exist, not built yet), **iOS only** / **Android only** (can't exist on the other platform; the reason is in Notes). The `docs-keeper` agent updates this file on every branch, and `parity-reviewer` checks it.

**Reference app:** <!-- iOS or Android: whichever is built first. Its code and tests decide any rule the other app hasn't built yet. -->

| Feature | iOS | Android | Notes |
| --- | --- | --- | --- |
| <!-- Example: Sign in with email --> | Pending | Pending | |

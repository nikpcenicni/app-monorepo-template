# __PROJECT_NAME__ website

The home page for both apps: what __PROJECT_NAME__ is, download links for the App Store and Google Play, and a footer crediting [__OWNER_NAME__](__OWNER_URL__). Code rules are in [CLAUDE.md](CLAUDE.md).

It's a static page with no build step:

| File | What it is |
| --- | --- |
| `index.html` | The page |
| `styles.css` | Styles, light and dark |
| `assets/` | App icon, favicon and a screenshot, copied from the apps (empty until they exist) |
| `package.json` | The site's own version (no dependencies) |

Preview it by opening `index.html` in a browser.

## Download links

Neither store listing is live yet, so both buttons show "Coming soon". When an app goes live, add its store URL as the `href` of `#download-ios` or `#download-android` in `index.html`; the button then becomes a link.

## Still to do

- Replace the placeholder features list with real copy once the apps have features.
- Add the app icon, favicon and a screenshot to `assets/`.
- Host the site and add a CI workflow (build check, and deploy from `main`) that only runs on changes under `apps/web/`, the way `.github/workflows/build.yml` does for iOS.
- Add a support page and a privacy policy page. App Store Connect and the Play Console need both URLs; then link them from the footer.

## Versioning

The site has its own version, separate from the apps' (see the root [CLAUDE.md](../../CLAUDE.md#branching-policy-always-follow)). It's in `package.json`; change it only when the site changes meaningfully. `scripts/version.sh` and the `v*` tags are for the apps, and changes that only touch `apps/web/` don't move them. Web changes still go through policy-named branches and PRs.

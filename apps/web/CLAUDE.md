# __PROJECT_NAME__ website

The apps' home page: what __PROJECT_NAME__ is, download links for iOS and Android, and a footer crediting __OWNER_NAME__. The branching policy and workflow in the [root CLAUDE.md](../../CLAUDE.md) apply here too. Paths below are relative to `apps/web/`.

## Code rules

- Plain static HTML and CSS: `index.html`, `styles.css` and `assets/`. No build step, no JavaScript and no package dependencies unless the user asks. Open `index.html` in a browser to preview it.
- Colours are custom properties at the top of `styles.css`: a dark palette by default and a light one under `prefers-color-scheme: light`. Match them to the apps' colours once they exist. Keep text at WCAG AA contrast in both.
- Store links: put each store's URL in the `href` of `#download-ios` or `#download-android`. A store link with no `href` shows as "Coming soon" and isn't clickable, so never use `href="#"`.
- The footer reads "© <year> __OWNER_NAME__" and links to __OWNER_URL__. Update the year by hand.
- Layout must work from 320px wide up, with no horizontal scrolling, and animation only under `prefers-reduced-motion: no-preference`.
- Images in `assets/` (`icon.png` at 256 px, `favicon.png` at 64 px, `screenshot.jpg`) are copied from the apps. Replace them when the app's icon or look changes.
- Claims about the apps (features, platforms, accessibility) must match the apps. Check them against [docs/feature-parity.md](../../docs/feature-parity.md) and the app READMEs. `web-engineer` makes the changes here, and `accessibility-auditor` checks them.
- The site's version is in `package.json`. Raise it only when the site changes meaningfully. It never affects `scripts/version.sh` or the `v*` tags.

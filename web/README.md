# Amortix website

Static site for the Amortix iPhone app: nine languages (the app's own: es en fr it de pt ar hi zh), a live
calculator per page, prerendered HTML for search engines and AI crawlers. Vite + React 19 + Tailwind v4, the same
pipeline as `Capital/web`.

```
npm install
npm test                  # engine figures against the iOS app, translation parity, copy rules
npm run dev               # http://localhost:5173/amortix/
npm run build             # client + SSR bundle + prerender of every page into dist/
node scripts/audit.mjs    # SEO and link audit over dist/
```

## Layout
- `src/engine.js` is a port of `amortix/Services/FinancialCalculator.swift`; `src/engine.test.js` pins the figures
  that appear in the app captures (449,04 / 498,57 / 76.512,32) and in the page copy.
- `src/content/<lang>.js` mirrors `es.js` key for key; `src/content.test.js` enforces it. A language appears on the
  site as soon as it is registered in `src/content/index.js`. Legal pages exist in Spanish and English only.
- `src/seo.js` builds head tags, JSON-LD (SoftwareApplication, WebPage, WebApplication, FAQPage, BreadcrumbList,
  ItemList), hreflang, sitemap, robots and llms.txt / llms-full.txt.
- `public/media/` is generated from `../marketing/` (`node make-gif.mjs`): animated WebP + framed GIF of the happy
  path, single views and the social card, in every language.

## Captures in every language
`sh marketing/capture.sh [es,en,...]` runs the UI test `amortixUITests/MarketingCaptures.swift` in the iOS Simulator
(iPhone 17 Pro Max): it launches the app once per language with its market, unlocked premium (no ads) and the
rating prompt silenced, and drives the journey: advanced mixed mortgage, results, chart, amortization table.
Then `cd marketing && npm install && node make-gif.mjs` produces the media.

## Deploy
`.github/workflows/pages.yml` publishes `dist/` to GitHub Pages at `https://albeasystems.github.io/amortix/` (repo
`albeasystems/amortix`). There is no domain yet: with one, build with `VITE_SITE_ORIGIN=https://your.domain BASE_PATH=/`
and update `ORIGIN`/`BASE` expectations in `scripts/audit.mjs`. The build also writes `/privacy.html`, `/terms.html`
and `/support.html` as redirects so the URLs the released app links to keep working.

## Things to know
- No prices, ratings, testimonials or download counts appear anywhere: none are verified. The purchase is described
  as "free with ads, one purchase removes ads, no subscription".
- ar / hi / zh copy has not been reviewed by a native speaker.
- Legal pages describe what the app does today (LevelPlay ads, ATT and consent form, one purchase). The older
  `files/privacy.html` said "no ads, no purchases", which contradicts the app; get both reviewed before publishing.
- `robots.txt` and `llms.txt` are generated into this folder's output. Crawlers read them at the domain root; on
  `albeasystems.github.io` that root belongs to the `albeasystems.github.io` repository (a custom domain fixes it).

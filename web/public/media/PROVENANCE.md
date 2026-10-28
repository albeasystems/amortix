# Provenance of the media in this folder

All rasters are real screenshots, none are generated or stock.

- Source: iOS Simulator, iPhone 17 Pro Max (1320x2868), Amortix debug build from this repository, captured on
  2026-10-28 with the status bar set to 9:41, premium unlocked (no ads) and the rating prompt silenced.
- Capture driver: `amortixUITests/MarketingCaptures.swift`, run by `marketing/capture.sh`. One launch per app
  language (es en fr it de pt ar hi zh) with that language's market, entering: mixed mortgage, 100.000 principal,
  30 years, 5 fixed years, Euribor 3,75 %, spread 0,75 %.
- Derived files: `marketing/make-gif.mjs` writes `amortix-<lang>-screen.webp` (animated loop of the five screens),
  `amortix-<lang>-framed.gif` (phone frame and caption), `views/<lang>/*.webp` (single screens, 600 px) and
  `og-<lang>.jpg` (1200x630 social card with the translated headline).
- App icon files (`icon-96.png`, `icon-256.png`, `favicon.png`) are resized from
  `amortix/Assets.xcassets/AppIcon.appiconset/amortix2.png`.
- Non-euro markets (en, pt, hi, ar) show their market's currency inside the captures, as the app does.

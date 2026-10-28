# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack
Vite + React 19 + Tailwind v4, prerendered to static HTML per page: the same pipeline as the sibling `Capital/web` site ("fíjate en la app Capital", confirmed by the user). Lives in `web/`; marketing assets (simulator captures, GIF) in `marketing/`. Hosting assumed GitHub Pages under `albeasystems.github.io/amortix/` until a domain exists; the user has no domain yet, so the site URL is one configurable constant in `src/site.js`.

## Users
Primary: a person with a mortgage, or about to sign one (Spain first, also Italy, France, Germany, Brazil, India, USA, Gulf), who wants to know the real monthly payment, the total interest, and whether making an early repayment pays off. They arrive from searches such as "calculadora de hipoteca", "amortizar hipoteca anticipada: ¿reducir cuota o plazo?", "cuadro de amortización", "hipoteca mixta Euribor" or from an AI assistant's answer.

## Product Purpose
Amortix is an iPhone app (also iPad) that simulates a mortgage with advanced conditions: fixed, variable (Euribor + spread) and mixed; French, linear and American repayment systems; early partial repayment (reduce payment vs reduce term, with the early-repayment fee per country law); extra payments; Euribor review and a stress test of rate rises; charts and a full amortization table. The website exists to be found by people asking those questions, answer them, and send them to the App Store.

## Positioning
One app that models the whole life of a mortgage per country's rules: auto early-repayment commission by market law, Euribor review, stress test, extra instalments, and a year-by-year amortization table with capital/interest charts. All calculation is on the device.

## Operating Context
Used with a bank offer or a deed in hand, entering capital, term, rate type, spread, Euribor, repayments. Output is read on a phone. Numbers are formatted per locale.

## Capabilities and Constraints
- Free download with ads (Unity LevelPlay) and a single one-time non-consumable purchase to remove ads (`com.albeasystems.amortix.premium`). No subscription. The website gives no price (no price source recorded); add it when confirmed.
- Tabs: Mortgage (Calculator, Rate review (Euribor markets only), Stress test), Amortization (Partial, Extra payment), Settings.
- 8 country markets: Spain, USA, India, Brazil, Italy, France, Germany, Gulf/Arabic. App localizations: ar, de, en, es, fr, hi, it, pt, zh-Hans.
- Informational tool, not financial advice nor a binding offer; the site must say so.
- App Store ID 6773757657. Publisher Albea Systems. Support contact albeasystems@gmail.com. Current legal pages (privacy, terms, support) exist in `files/`; they must keep working.
- Site languages shipped first: es and en, with the content layer built so the other app languages are added by registering a file.

## Brand Commitments
Name "Amortix". Sibling of Capital, SnowballFI, Measuro, Divix, NotasPAU from Albea Systems. Voice: direct, precise, no hype. The existing site's green identity (#10b981) is a hypothesis from the incumbent, not binding; visual world is decided in the design step.

## Evidence on Hand
- Simulator captures in `../Images/amortix/` and the live iPhone 17 Pro Max simulator, plus the app code and unit tests (`amortixTests/FinancialCalculatorTests.swift`).
- No ratings, review counts, downloads, testimonials, press or customers exist. The current `files/index.html` testimonials, stars and stats are unverified and must NOT be reused. Do not fabricate social proof.

## Product Principles
1. Answer the question first (what will I really pay, does repaying early pay off), then offer the app.
2. Every figure on the site is computed by a port of the app's formulas or taken from a real capture.
3. Be plain about what is paid: free with ads, one purchase removes ads.
4. Informational, not advice; confirm terms with the bank.
5. Be findable by both search engines and AI assistants: one clear answer per page, structured data, llms.txt.

## Accessibility & Inclusion
WCAG AA contrast, labelled keyboard-operable calculator inputs, `prefers-reduced-motion` and `prefers-color-scheme` respected, correct `hreflang` and `dir="rtl"` when Arabic is added, locale-correct number formatting.

---
name: Amortix
description: Near-white paper, one blue for the capital you borrow, one amber for the interest you pay; a statement-style mortgage site drawn around a single capital/interest bar.
colors:
  paper: "#fbfbfc"
  paper-2: "#f2f4f7"
  ink: "#0e1726"
  ink-2: "#566275"
  capital-blue: "#2269de"
  capital-blue-soft: "#c9d8f5"
  on-blue: "#ffffff"
  interest-amber: "#a85600"
  interest-amber-bar: "#f0a135"
  interest-amber-soft: "#fdf1df"
  rule: "#e3e7ee"
  rule-strong: "#c5ccd8"
typography:
  display:
    fontFamily: "Geist Variable, system-ui, -apple-system, Segoe UI, sans-serif"
    fontSize: "clamp(2.4rem, 6vw, 5rem)"
    fontWeight: 650
    lineHeight: 1.04
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "clamp(1.75rem, 3.4vw, 2.75rem)"
    fontWeight: 650
    lineHeight: 1.1
    letterSpacing: "-0.03em"
  title:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1.1875rem"
    fontWeight: 620
    lineHeight: 1.3
    letterSpacing: "-0.015em"
  body:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.6
  lede:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "clamp(1.1rem, 1.6vw, 1.3rem)"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Geist Variable, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
rounded:
  sm: "10px"
  md: "14px"
  bar: "12px"
  device: "2.4rem"
  pill: "999px"
spacing:
  zone: "clamp(3.5rem, 7vw, 6.5rem)"
  gutter: "2.5rem"
  stack: "1.75rem"
  field-y: "0.6rem"
components:
  button-primary:
    backgroundColor: "{colors.capital-blue}"
    textColor: "{colors.on-blue}"
    rounded: "{rounded.sm}"
    padding: "0.85rem 1.4rem"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: "0.85rem 1.4rem"
  field-input:
    backgroundColor: "{colors.paper-2}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: "0.6rem 0.8rem 0.5rem"
  row-hot:
    backgroundColor: "{colors.interest-amber-soft}"
    textColor: "{colors.interest-amber}"
    rounded: "{rounded.sm}"
    padding: "1rem 1.1rem"
  panel:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
  chip:
    backgroundColor: "{colors.paper-2}"
    textColor: "{colors.ink-2}"
    rounded: "{rounded.pill}"
    padding: "0.15rem 0.6rem"
---

# Design System: Amortix

## Overview

**Creative North Star: "The Loan Statement"**

Amortix is a bank statement made legible: near-white paper, near-black ink, hairline-divided zones, and figures that line up in columns. The world is inherited from the sibling Capital site; what is Amortix's own is the colour logic and the signature. Blue is the capital you borrow and every action; amber is the interest you pay on top. The two never trade jobs, so a visitor can read money by colour alone.

The site is flat and quiet so the numbers carry it. Depth comes from paper tone and hairlines, never from shadow, except on the phone frames that hold real app captures. Dark mode is the same roles on near-black, not a second design.

**Key Characteristics:**
- One bar, drawn to scale, split capital (blue) and interest (amber): the signature, shown in the hero, the calculator result and the closing mini bar.
- Geist Variable throughout; tabular figures wherever a number appears.
- Statement rows: label, dotted leader, figure; one amber "hot" row per result.
- Filled fields with a ruled underline; flat panels with a 1px hairline.
- Only real captures and computed figures; no invented proof.

## Colors

A cool paper-and-ink neutral ground with exactly two chromatic roles, blue and amber.

### Primary
- **Capital Blue** (`capital-blue`): primary buttons, focus ring, caret and accent-color, the capital segment of every bar and chart, active language item. Selection tint is this blue at 28%.
- **Capital Blue Soft** (`capital-blue-soft`): quieter blue for secondary chart fills.

### Secondary
- **Interest Amber** (`interest-amber`): text and figures that mean interest (the hot row value, interest caption, interest chart labels, interest line strokes). Dark enough for text on paper.
- **Interest Amber Bar** (`interest-amber-bar`): the fill for interest segments and bars; too light for text.
- **Interest Amber Wash** (`interest-amber-soft`): only the background of the one hot row (total interest).

### Neutral
- **Paper** (`paper`) page and panel ground; **Paper Wash** (`paper-2`) fields, footer, chip, hover tint.
- **Ink** (`ink`) text and line-chart strokes; **Slate Ink** (`ink-2`) labels, ledes, axis text.
- **Rule** (`rule`) zone borders, row dividers, gridlines; **Rule Strong** (`rule-strong`) input underlines, table heads, outlines of quiet buttons, device frame.

**Dark mode (prefers-color-scheme, same roles):** paper #0b0f17, paper-2 #131a26, ink #edf1f7, ink-2 #9aa6b8, blue #6fa0ff (soft #2a3b5c), amber text #ffb15c, amber bar #d98a26, amber wash #2b2113, rule #1f2735, rule-strong #364156. Text on blue becomes #0b0f17 (also the chart on-line label). The App Store stamp stays #2269de with white text in both modes. Bar interest labels use fixed #1d1403.

### Named Rules
**The Two Jobs Rule.** Blue means capital or an action; amber means interest. Never use amber for a button, never use blue for interest, never add a third chromatic hue.
**The Amber Text Rule.** Amber text uses the darker `interest-amber`; the lighter bar amber is for fills only.

## Typography

**Display / Body / Label Font:** Geist Variable (fallback system-ui, -apple-system, Segoe UI, with Noto Sans Arabic/Devanagari and PingFang SC / Microsoft YaHei in the stack; ja and ko swap in their own CJK stacks).

**Character:** One neutral grotesque, tight and heavy at display size, relaxed at body size. Hierarchy is made by size and weight, not by a second family.

### Hierarchy
- **Display** (650, clamp(2.4rem, 6vw, 5rem), 1.04, -0.035em): page H1 only; capped near 18-20ch.
- **Headline** (650, clamp(1.75rem, 3.4vw, 2.75rem), 1.1): zone titles (H2).
- **Title** (620, 1.1875rem, 1.3): card and FAQ question titles (H3).
- **Lede** (400, clamp(1.1rem, 1.6vw, 1.3rem), 1.5, slate ink): one paragraph under a heading, max ~65ch.
- **Body** (400, 1.0625rem, 1.6): running text, measure 65ch.
- **Label** (0.875rem / 0.8125rem cell label, slate ink): field labels, captions, table heads.
- **Figure** (tabular-nums; field input 1.2rem/520; row value 1.125rem/560; hot row 1.6rem/680): every number.

Letter-spacing is zeroed and line-height opened (1.25 headings; 1.8-1.85 body) for ar, hi, zh, ja, ko; ko keeps words whole.

### Named Rules
**The Tabular Figures Rule.** Every amount, percentage, axis tick and table cell uses tabular numerals so columns align.

## Layout

A single centred wrap, `min(100% - 2.5rem, 76rem)` (2rem gutters under 640px), holding 12-column grids at lg (hero 7/5, calculator inputs and result split, FAQ 4/8). Pages stack as full-width zones separated by a 1px rule, each with vertical padding of clamp(3.5rem, 7vw, 6.5rem); the first sits tight under the header. Gaps run 1.75rem (stacks), 2.5rem (columns), 3rem to 3.5rem (hero). Reading measure is capped at 65ch.

The capture rail is a horizontally scrolling, scroll-snapped list of phone frames; on lg the phone width is sized so five fit the wrap exactly, on mobile it scrolls with 1rem inset. The hero phone is 17rem wide (21rem on lg). Charts and the cost bar are LTR inside RTL pages; the wide chart is replaced by a compact one under 640px. A sticky mobile mini strip class exists in the CSS but is not used on any page.

## Elevation & Depth

Flat by default: depth is paper vs paper-wash tone and 1px hairlines. Shadows exist in two places only.

### Shadow Vocabulary
- **Phone frame** (`box-shadow: 0 28px 48px -28px color-mix(in oklab, ink 38%, transparent), 0 2px 6px color-mix(in oklab, ink 8%, transparent)`): real app captures only.
- **Language popover** (`0 12px 32px -12px rgb(14 23 38 / 0.28)`): the open menu, which floats.
- **Logo hairline** (`0 0 0 1px rule-strong`): a ring, not a shadow, around the app icon.

### Named Rules
**The Phone-Only Shadow Rule.** Cards, panels, buttons and fields never carry a shadow; only the device frame and the floating menu do.

## Shapes

Soft but disciplined radii: 10px (buttons, fields' top corners, hot row), 14px (panels, language list), 12px (the cost bar), 2.4rem (phone frame, with 2rem screen inside), full pill for chips. Inputs are rounded on top only, with a 2px rule-strong underline that turns blue on focus. Bars and chart rects are near-square (1.5px) with a 3px gap between capital and interest segments. Hairlines are 1px; table heads and input underlines are heavier (1.5-2px).

## Components

### Buttons
- **Shape:** 10px radius, 1.5px border in the fill colour, weight 620, 1rem.
- **Primary (App Store stamp):** Capital Blue fill, white text, padding 0.85rem 1.4rem; compact in the header (0.5rem 1rem, 0.875rem). Hover darkens the blue 14% toward black; active moves down 1px.
- **Quiet:** transparent, ink text, rule-strong border; hover paper-wash fill and slate border.

### Inputs / Fields
- **Style:** label above in slate 0.875rem; wrapper is paper-wash with 10px top corners and a 2px rule-strong underline; value 1.2rem/520 tabular; unit suffix in slate.
- **Focus:** the underline turns blue (focus-within); hover tints the fill toward blue. Native spinners are removed; selects are custom-flat.

### Statement Rows
Label, a dotted rule-strong leader, then a tabular figure, with a 1px rule divider. The single **hot row** drops the leader and divider, sits on the amber wash, and sets its figure in amber at 1.6rem/680.

### Tables
Full-width collapsed tables, 0.9rem, right-aligned figures (first column left), heads 0.8125rem slate with a 1.5px strong rule, row dividers 1px, none under the last row.

### Cards / Containers (Panel)
1px rule border, 14px radius, paper fill, no shadow. Used for the free/ads/data triptych (divided into three cells) and the closing call to action (with a mini capital/interest bar).

### Navigation
Header with a bottom hairline: logo (34px icon + bold wordmark) left; three text links (md and up, underline on hover), language menu, compact stamp. The language menu is a native details/summary: globe, name (code on small screens), chevron; list is a two-column panel, current item blue and bold on paper-wash. Focus ring is 2px blue, 3px offset. Footer is paper-wash with a top hairline and a four-column title block.

### FAQ
Native details with title-weight questions (blue on hover) and a plus mark whose vertical stroke scales away when open; rows divided by hairlines.

### Cost Bar and Charts (signature)
The cost bar is 3.5-4rem high, 12px radius, a blue capital segment sized to its share and an amber interest segment filling the rest, percentages inside at semibold, then a two-column caption of capital (blue figure) and interest (amber figure). Year bars stack capital under interest on a 960x380 viewBox with 20-unit axis text, round-number ticks (at most five), hairline gridlines and an axis title; balance lines are ink strokes distinguished by dash pattern, never colour. Bars draw in once (left to right, or upward with a small stagger) and the home cost bar draws on scroll where supported; reduced motion shows everything static.

### Phone Captures
Real simulator captures only, inside the device frame (1px strong border, 0.4rem padding, 2rem-radius screen), each with a caption below.

## Do's and Don'ts

### Do:
- **Do** show the capital/interest split as one bar whenever a result is shown, blue first, amber second.
- **Do** put figures in tabular numerals and give every amount its currency in the visitor's locale.
- **Do** keep one amber hot row per result block; everything else in the block stays ink and slate.
- **Do** keep chart text at 20 viewBox units or larger and give every chart an axis title and a legend.
- **Do** use ease-out (cubic-bezier(0.16, 1, 0.3, 1)) at 140-200ms for state changes and 700-900ms for the one-time draw-in; respect reduced motion.
- **Do** use only captured screens and computed figures as proof.

### Don't:
- **Don't** spend a third hue, a gradient, or amber on actions.
- **Don't** add shadows to cards, panels, buttons or fields.
- **Don't** separate zones with background colour blocks; use the 1px rule.
- **Don't** encode data series by colour alone in line charts; use dash patterns.
- **Don't** set display text in a second family or let letter-spacing stay negative in Arabic, Hindi or CJK scripts.

## Known gaps and drift (not part of the system)

- The mobile sticky mini strip (`.sticky-strip`) is defined in CSS but not wired into any Amortix page; do not treat it as a live component until it is used and reviewed.
- Arabic, Hindi and Chinese copy has not been reviewed by native speakers.
- The finish review screenshotted the Spanish desktop, dark desktop and mobile views only; Arabic (RTL), tablet widths and the non-Spanish pages have not been visually reviewed.

# Favicon / app icon UX delta
**Status: LOCKED rev 1.0 — 2026-11-05 ~6:01 PM CT**
**Decision: Bill picked option A (Branch dot) via Erlich.**

## Mark
A terracotta timeline dot with a thick moss ring.
A short moss 45° elbow leader rises to a smaller moss branch dot.
The standard mark sits on a parchment rounded square.

## Exact asset colors and roles
- `#FBF7F2` — parchment: standard, touch, and maskable backgrounds.
- `#8B5E4B` — terracotta: solid primary timeline dot.
- `#5B7F3A` — branchMoss: primary-dot ring, elbow leader, and branch dot.
- No other colors are used in the source glyph or icon backgrounds.

## Asset inventory and purpose
- `favicon-16.png` — 16 × 16 px; small browser favicon.
- `favicon-32.png` — 32 × 32 px; standard browser favicon.
- `favicon.ico` — embedded 16, 32, and 48 px images; ICO fallback.
- `apple-touch-icon.png` — 180 × 180 px; opaque Apple touch icon.
- `icon-192.png` — 192 × 192 px; standard web app icon.
- `icon-512.png` — 512 × 512 px; large standard web app icon.
- `icon-maskable-192.png` — 192 × 192 px; small maskable app icon.
- `icon-maskable-512.png` — 512 × 512 px; large maskable app icon.
- `source.svg` — master SVG for 32, 48, 180, 192, and 512 px assets.
- `source-16.svg` — hand-tuned, pixel-snapped 16 px SVG.
- `source-maskable.svg` — full-bleed maskable master SVG.

## Maskable and small-size rules
Maskable backgrounds are full bleed, with no rounded transparent corners.
All glyph pixels must fit a centered circle with diameter 0.8 × icon width.
Measured outside-circle glyph pixels: zero at both 192 and 512 px.
At 16 px, retain the dot, thick ring, short elbow, and small branch dot.
Use the dedicated 16 px source rather than mechanically reducing the master.
Keep strokes and gaps at least one device pixel at the smallest size.

## Delivery boundary
Asset source path: `/workspace/favicon/A/`.
This is a web build only; it does not include native app store assets.
HTML, manifest, favicon links, and other wiring are for the coding agent.
No runtime behavior or additional wiring is specified by this document.

# Mortang — Tell Me a Story · DESIGN.md (Memory Album design system)

**Status:** LOCKED rev 1.0, 2026-11-14 (Mugatu · UXD). The 7 timeline tokens were approved by Bill at 11:24 AM CT on 2026-11-14 for the timeline rail split ([PR #215](https://github.com/wmfmorgan/mortang-tell-me-a-story/pull/215)).

This is the single catalog of Memory Album design tokens that `apps/tell_me_a_story/lib/core/theme/album_theme.dart` cites ("UXD DESIGN.md"). Code is the source of truth for values: `album_theme.dart` defines them and `test/core/theme/album_theme_test.dart` (`locked hex values`) locks them. Screen notes in `docs/ux/` list only the tokens a single screen uses.

Rules: always use a token, never a raw color literal, in widget code. No glow anywhere. Text and icons meet WCAG 2.2 AA contrast on their surface. Tap targets are at least 44×44.

## Tokens

### Color: core

| Token | Value | Use |
|---|---|---|
| `albumParchment` | `Color(0xFFFBF7F2)` | App surface: scaffold, canvas, app bar, cards, dialogs, sheets, inputs; `onPrimary` / `onSecondary` / `onError` |
| `albumInk` | `Color(0xFF2C2416)` | Primary text and icons (`onSurface`) |
| `albumTerracotta` | `Color(0xFF8B5E4B)` | `primary`: filled buttons, progress; also `error` |
| `albumSage` | `Color(0xFF7A8B74)` | `secondary` / `tertiary`: card, chip, input and outlined-button borders (at the alphas set in the theme) |
| `branchMoss` | `Color(0xFF5B7F3A)` | Branch marks (branch callout ring and border) |
| `albumDialogSurface` | `Color(0xFFFFF8F6)` | Dialog surface |
| `albumModalScrim` | `Color(0x661C140C)` | Modal scrim |
| `albumModalBorder` | `Color(0xFFE6DCD1)` | Modal border |
| `albumPillFill` | `Color(0xFFF6F1EB)` | Pill fill |
| `albumPillBorder` | `Color(0xFFE7DECE)` | Pill border |
| `albumBackdropClear` | `Colors.transparent` | Clear backdrop |

### Color: timeline (added 2026-11-14, PR #215)

| Token | Value | Use |
|---|---|---|
| `albumInkFaint` | `Color(0x332C2416)` (ink at 20%) | `_FarRail` rail line |
| `albumInkDim` | `Color(0xB32C2416)` (ink at 70%) | `_ZoomSwitch` dim label |
| `albumParchmentClear` | `Color(0x00FBF7F2)` (parchment at 0%) | `_FullCardRail`, both gradient stops. Not `Colors.transparent`, so the fade stays parchment-tinted |
| `albumBlush` | `Color(0xFFF5DED6)` | `_FullCardDot` focus shadow; filled `_FullChip` |
| `albumBlushWash` | `Color.fromRGBO(0xF5, 0xDE, 0xD6, 0.3)` (blush at 0.3) | `_FullCard` focus shadow. Equals `Color(0xFFF5DED6).withValues(alpha: 0.3)`; don't round it to an 8-bit hex |
| `albumPaleRose` | `Color(0xFFF5ECE9)` | Unfilled `_FullChip` |
| `albumWhite` | `Color(0xFFFFFFFF)` | `_FullCard` surface when the card is not branched |

Focus shadows made from blush are soft focus cues, not glow: keep them tight and don't animate a halo.

### Shape

| Token | Value | Use |
|---|---|---|
| `albumCardRadius` | `12.0` | Cards; bottom sheet top corners |

Buttons, chips and inputs use radius 8; dialogs use 16 (set in `albumTheme()`).

### Type

| Role | Family | Use |
|---|---|---|
| Headings (`headline*`, `titleLarge`, `titleMedium`, app bar title) | Newsreader, w600 | Titles |
| Body (`body*`) | Literata | Reading text; photo editor Text tool |
| Labels (`titleSmall`, `label*`, buttons) | Source Sans 3 | Controls and labels |

## Changelog

- rev 1.0, 2026-11-14: first repo copy of the catalog. It records the existing `album_theme.dart` tokens and adds the 7 timeline tokens Bill approved at 11:24 AM CT for the rail split (PR #215).

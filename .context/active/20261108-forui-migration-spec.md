# Spec: finish the forui migration

## Summary
The timeline and tree views run on forui and album tokens (#194); every other screen still uses ad-hoc Material widgets, direct font sizes and raw colours.
Family members see seven segmented controls, six chip styles and nine primary-button colours for the same roles.
This work moves every remaining screen onto the same component set and tokens, so the app reads as one warm memory album on iPad and web.

## Background
- Users: family members capturing and reading stories, mostly on iPad (`.context/project-context.md`).
- Today the app mixes forui (timeline, tree) with per-screen Material styling. The review lists 32 findings: `.context/active/20261108-ui-ux-review.md`.
- Baseline on `chore/context-forui-timeline` (`apps/tell_me_a_story/lib`, measured 2026-11-08):
  - Colour skip list (`test/architecture/no_hardcoded_colors_test.dart`): 16 files.
  - Material button constructors (`FilledButton`, `OutlinedButton`, `TextButton`, `ElevatedButton`, incl. `.icon`): 93; `*.styleFrom` overrides: 59.
  - `fontSize:` literals: 249 (21 distinct sizes); `GoogleFonts.*(` calls: 250.
  - Material chips (`Chip`, `FilterChip`, `ChoiceChip`, `RawChip`, `InputChip`, `ActionChip`): 9.
  - Dialog entry points outside `lib/ui/dialogs` and `lib/ui/album/album_chrome.dart`: 9 (`showGeneralDialog` 7, `AlertDialog` 1, `showDialog` 1).
  - At 744 pt the header drops the family name (UX-15).

## Stakeholders
- David (owner): requester and approver.
- Family members: users.

## Goals
- G1: The colour skip list holds 0 files and its ceiling is 0 (today: 16).
- G2: `lib/` has 0 Material button constructors and 0 `styleFrom` overrides (today: 93 and 59).
- G3: `lib/` outside `core/theme/` has 0 `fontSize:` literals and 0 `GoogleFonts.*(` calls (today: 249 and 250).
- G4: `lib/` has 0 Material chips (today: 9).
- G5: `lib/` opens dialogs only through the shared dialog helpers; 0 direct `showGeneralDialog`, `showDialog` or `AlertDialog` elsewhere (today: 9).
- G6: An architecture test fails the build when G1-G5 regress.
- G7: At 744×1133 every screen with the shared header shows the current family name (today: hidden).
- G8: No behaviour regresses: `just test` passes with no fewer tests than before each slice; e2e passes 9/9; every changed golden is reviewed.

## Non-goals
- New features, screens, endpoints or tables.
- Server changes.
- Owner-gated product decisions (UX-11 no-family landing, UX-12 start-family destination, UX-18 in-page filled buttons): their slices ship the component swap and leave behaviour as it is until David decides.
- Account deletion UI (D7) and unpublish (D12).

## Constraints
- Components come from forui ^0.27, skinned by `albumForuiTheme()`; Material stays only where forui has no equivalent (durable decision in `.context/project-context.md`).
- Colours, radii, spacing and type come only from album tokens; a new token or copy string needs David's approval (`AGENTS.md`).
- Flutter 3.47.7 and current dependency majors stay pinned.
- Touch targets stay ≥ 44 pt.

## Open questions
- UX-31 / UX-32: approve `albumSoftInk` and a shadow token? Owner: David. `can wait`.
- UX-12: change the copy or the route after Start a family? Owner: David. `can wait`.
- UX-11: where does a signed-in user with no family land? Owner: David. `can wait`.
- UX-18: which in-page actions may stay filled terracotta beside New story? Owner: David. `can wait`.

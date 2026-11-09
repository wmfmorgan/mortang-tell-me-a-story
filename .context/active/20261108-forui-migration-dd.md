# DD: finish the forui migration

## Summary
This DD moves every screen outside the timeline and tree onto forui components and album tokens, one feature slice per TDD.
It serves G1-G8 of [20261108-forui-migration-spec.md](20261108-forui-migration-spec.md).
Guards land first, so each slice shrinks a measured allowlist instead of a hand count.

## Glossary
- **album token**: a constant or class member in `lib/core/theme/album_theme.dart` (colours, `AlbumSpace`, `AlbumRadius`, `AlbumBreakpoint`, `AlbumTarget`, `AlbumText`).
- **forui theme**: `albumForuiTheme()`, installed for every route by `albumAppBuilder`.
- **slice**: one feature folder (or shared UI area) migrated in one TDD.
- **guard**: an architecture test under `test/architecture` that counts a banned pattern per file against an allowlist.
- **allowlist**: the guard's list of files still allowed a banned pattern; it only shrinks.
- **shared dialog helper**: `showAlbumDialog`, `showBlurredCard` or `showFamilyBlurDialog` (with its siblings in `lib/ui/dialogs`).
- **scoped messages**: the `scopedMessages` option of a shared dialog helper; the card gets its own `ScaffoldMessenger`.
- **button mapping**: filled → `FButton` primary, outlined → outline, text → ghost, destructive confirm → destructive.
- **segmented control**: `ViewSwitch<T>`.
- **chip**: `AlbumChip`.

## Current state
```
MaterialApp.router (theme: albumTheme, builder: albumAppBuilder -> FTheme)
  |-- timeline, tree ............ forui + album tokens (done in #194)
  `-- every other feature ........ Material widgets + styleFrom + fontSize + Color literals
        |-- dialogs: showGeneralDialog / showDialog / AlertDialog / shared helpers (mixed)
        `-- chips: Chip / FilterChip / ChoiceChip / RawChip
```

## Target state
```
MaterialApp.router (theme: albumTheme, builder: albumAppBuilder -> FTheme)
  |-- features/* ......... FButton, ViewSwitch, AlbumChip, textTheme roles, album tokens
  |-- lib/ui/dialogs ..... shared dialog helpers (blur shell + forui buttons)
  `-- test/architecture .. guards for colours, buttons, font sizes, chips, dialogs
```
- `features/*` render only forui components, shared `lib/ui` widgets, and album tokens.
- Shared dialog helpers are the only route to a dialog.
- Guards fail the build when a file outside its allowlist uses a banned pattern.

## Data flow
None. The work changes widgets only; gateways, session state and the server stay as they are.

## Decisions
1. **Guards first.**
   - Options: count by hand per PR; one guard per goal with a shrinking allowlist.
   - Choice: one guard per goal (G2-G5), seeded with today's files, plus the existing colour guard (G1).
   - Why: slices then prove progress by deleting allowlist lines, and nothing regresses between slices.
2. **Dialogs keep the album blur shell.**
   - Options: forui `FDialog`; the existing shared dialog helpers.
   - Choice: shared dialog helpers, restyled with forui buttons and tokens.
   - Why: the sigma-4 blur card is a locked UX anchor; `FDialog` would change it.
3. **Text fields stay Material in this spec.**
   - Options: `FTextField` now; later spec.
   - Choice: later spec. Fields use `AlbumFieldBorder` and album tokens in this work.
   - Why: field migration changes focus, keyboard and validation behaviour on every form; it needs its own goals.
4. **SnackBar stays the error pop-up.**
   - Options: forui toast; SnackBar.
   - Choice: SnackBar. Modals that stay open after an error use scoped messages.
   - Why: the SnackBar is the established error pop-up, and a toaster needs a new app-level host.
5. **Typography by role.**
   - Choice: features use `Theme.of(context).textTheme` roles and `AlbumText`. `GoogleFonts` appears only in `core/theme/`.
   - Why: the 21 sizes collapse to the theme's roles. A size with no matching role halts the slice (see Risks).
6. **Owner-gated behaviour stays put.**
   - Choice: slices that touch UX-11, UX-12 or UX-18 swap components and keep today's behaviour and copy.
   - Why: those need David's decision (spec open questions).
7. **Test harnesses.**
   - Choice: every test that renders a migrated widget passes `builder: albumAppBuilder` to its `MaterialApp`.
   - Why: forui widgets need an `FTheme` ancestor.

## Work breakdown
| TDD | Scope | Goal IDs | Depends on | Status |
|---|---|---|---|---|
| guards | Button, font-size, chip and dialog guards seeded with today's allowlists | G6 | none | planned |
| dialog-helpers | `lib/ui/dialogs`, `showAlbumDialog`: forui buttons, tokens | G2, G3, G5 | guards | planned |
| header | `lib/ui/album` header and chrome; compact header below `AlbumBreakpoint.sidebar` keeps the family name (UX-15, UX-16, UX-22) | G1-G3, G7 | guards | planned |
| all-stories | `features/all_stories` (group-by → segmented control) | G1-G4 | guards | planned |
| stories | `features/stories` capture and reader (UX-14, UX-24, UX-25) | G1-G5 | dialog-helpers | planned |
| family | `features/family` landing, manage, start dialogs | G1-G5 | dialog-helpers | planned |
| invites | `features/invites`, invite sign-in (tabs → segmented control) | G1-G3, G5 | dialog-helpers | planned |
| people | `features/people` modals and profile | G1-G5 | dialog-helpers | planned |
| places | `features/places` picker and map (UX-26) | G1-G3, G5 | dialog-helpers | planned |
| search | `features/search` (UX-17) | G1-G4 | guards | planned |
| settings | `features/settings` (tabs, visibility pills) | G1-G4 | guards | planned |
| drafts | `features/drafts` (filter chips → chip) | G1-G4 | guards | planned |
| auth | `features/auth` sign-in | G1-G3 | guards | planned |
| comments-perspectives | `features/comments`, `features/perspectives` | G1-G3 | guards | planned |
| tokens-followup | `albumCardRadius`, `AlbumFieldBorder`, theme radii, soft-ink and shadow tokens (UX-06, UX-21, UX-31, UX-32) | G1, G3 | all feature slices | planned |
| ipad-pass | Owner device checklist at 1280×800, 1133×744, 744×1133 (UX-29) | G7, G8 | all feature slices | planned |

Every slice also checks G8: `just test` count, e2e 9/9 when its flows change, and reviewed goldens.

## Risks and open questions
- A font size with no matching text-theme role needs a new `AlbumText` style, which is a new token. Owner: David. Blocks the slice that meets it.
- UX-31 / UX-32 token approval. Owner: David. `blocks tokens-followup`.
- UX-11 and UX-12 decisions. Owner: David. These change behaviour only after a decision; `family` ships without them.
- UX-18 in-page filled buttons: until decided, slices map today's filled buttons to `FButton` primary. Owner: David.
- Golden churn: each slice regenerates only its own goldens and reviews every changed PNG. Owner: implementer.

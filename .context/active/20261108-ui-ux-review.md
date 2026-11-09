# UI/UX review: Tell Me a Story Flutter app

Status: active findings doc, dated 2026-11-08. Owner: David. Delete it, per `.context/writing-specs.md#lifecycle`, once every row in `## Work breakdown` is `done`. Move any durable decision into `.context/project-context.md` first.

## Scope and method

- **App:** `apps/tell_me_a_story` (Flutter web build of the iPad-first client), served by `just run` on `127.0.0.1:3000` against `just server` on `:8080`. The UI was the base commit `32ad96e`, before any forui work.
- **Live capture:** drove headless Chromium at device pixel ratio 1.
  - Signed in as `david@example.com` with code `111111` and started "The Morgan Family".
  - Published 5 photo-free stories in 4 decades (1974, 1981, 1988, 1995, 2003) and left 1 draft.
  - A second account (`newcomer@example.com`) captured the no-family first run.
- **Screenshots:** 67 PNGs in `20261108-ui-ux-review/`, named `<screen>-<1280x800|744x1133>.png`: 37 at 1280×800 and 30 at 744×1133 (iPad portrait).
- **Environment workarounds:**
  - **Places:** no `MAPBOX_ACCESS_TOKEN` is set locally, so the place picker cannot search. A place is required to publish, so the three places ("The farm", "Grandma's house", "Lake cabin") were seeded as favourites through the `place/create` endpoint, then picked in the UI. See UX-29.
  - **Stale server:** the first server on `:8080` was a stale process with no `story/listPublishedInTree`. The orchestrator restarted it, and the tree screens were captured afterwards. `family-tree-error-1280x800.png` comes from the stale server and is kept only as evidence of the error-state styling.
- **Code evidence:** `file:line` references use **lines at 32ad96e**, read with `git show 32ad96e:<path>`, and are relative to `apps/tell_me_a_story/lib/` unless the path starts with `test/`. Later commits on this branch move these lines.

## Screen inventory

| Route | File | Purpose | Screenshots |
|---|---|---|---|
| `/` | `features/auth/sign_in_page.dart`, `sign_in_code_form.dart` | Signed-out landing, email then 6-digit code | `sign-in-*`, `sign-in-code-*` |
| `/invite/:token` | `features/auth/invite_sign_in_page.dart`, `features/invites/invite_accept.dart` | Invite landing and accept | not captured (needs a real token) |
| `/family` | `features/family/family_landing_page.dart` | Signed-in home: family cover, "Latest" (past 7 days) | `family-landing-*`, `family-landing-empty-1280x800`, `family-landing-latest-1280x800` |
| `/timeline` | `features/timeline/timeline_page.dart`, `zoom_switch.dart`, `rails/*`, `origin_banner.dart`, `filter/filter_panel.dart` | Family timeline at Decades/Years/Days zoom, filters sidebar or drawer | `timeline-decades-*`, `timeline-years-*`, `timeline-days-*`, `timeline-filters-*`, `timeline-nofamily-*` |
| `/family/:id/tree` | `features/timeline/tree/family_tree_page.dart`, `tree_graph_view.dart`, `treemap_view.dart` | Whole-tree page: graph view and treemap overview (By family/decade/person) | `family-tree-graph-*`, `family-tree-overview-*`, `family-tree-error-1280x800` |
| `/family/:id/stories` | `features/all_stories/all_stories_page.dart`, `all_stories_card.dart` | All published stories, searchable, grouped by Date/Member/Place | `all-stories-*`, `all-stories-by-place-*` |
| `/stories/new`, `/stories/:id/edit` | `features/stories/new_story_page.dart`, `photo_strip.dart` | Capture/edit modal: title, body, photos, timeframe, people, place | `story-capture-*`, `story-capture-validation-1280x800`, `story-capture-add-person-*`, `add-person-modal-1280x800`, `place-picker-*` |
| `/stories/:id` | `features/stories/story_reader_page.dart`, `reader_meta.dart`, `features/comments/comment_composer.dart` | Reader modal: meta chips, body, photos, perspectives, comments | `story-reader-*`, `comment-composer-*` |
| `/stories/:id/perspective` | `features/perspectives/add_perspective_page.dart` | Add an alternate telling | `add-perspective-*` |
| (dialog) | `features/people/person_profile_dialog.dart`, `add_person_modal.dart`, `edit_person_dialog.dart` | Person profile with their stories; add/link people | `person-profile-*`, `story-capture-add-person-*` |
| (dialog) | `features/places/place_picker_modal.dart`, `place_map.dart` | Choose place: Favorites / Recents / All Places tabs plus map | `place-picker-*` |
| `/drafts` | `features/drafts/drafts_page.dart` | My drafts with "missing X" filters | `drafts-*` |
| `/search` | `features/search/search_page.dart`, `search_recents.dart` | Full-screen search: facets, recents, results | `search-*`, `search-results-*` |
| `/settings` | `features/settings/settings_page.dart` | Profile, family and notification settings | `settings-*` |
| `/manage-families` | `features/family/manage_families_page.dart`, `start_family_dialog.dart` | Family hub; start a family | `manage-families-*`, `manage-families-empty-*`, `start-family-dialog-1280x800` |
| `/manage-families/:familyId` | `features/family/manage_family_page.dart`, `add_co_owner_dialog.dart`, `transfer_ownership_dialog.dart`, `delete_family_dialog.dart` | Rename, co-owners, members, delete | `manage-family-*` |
| (header menus) | `ui/album/album_header.dart`, `features/invites/invite_modal.dart`, `features/family/start_timeline_dialog.dart` | Family menu (tree, invite, add branch, manage), avatar menu (settings, logout) | `header-family-menu-*`, `header-avatar-menu-*`, `family-menu-nofamily-1280x800`, `invite-modal-*`, `start-timeline-dialog-*` |

Routes are declared in `core/router/app_routes.dart:19-51` and wired in `app/app_router.dart:74-331`. `AlbumHeader` appears on 8 pages: family landing, timeline, tree, all stories, drafts, settings, manage families and manage family. Search, add-perspective, capture and reader each draw their own chrome.

## Findings

Severity: **high** means it blocks or misleads a core task, or breaks the brand system across many screens. **med** means visible inconsistency or a maintenance cost. **low** means polish.

### UX-01 (high): Primary buttons are restyled per call site
- **Screen:** all.
- **Evidence:** 24 `FilledButton.styleFrom(` sites, the theme's included (`core/theme/album_theme.dart:325`).
  - **Foregrounds disagree:**
    - `albumParchment` (e.g. `features/stories/new_story_page.dart:911`)
    - `albumOnAccent` (`ui/album/album_header.dart:286`)
    - the literal `Color(0xFFFFF6F3)`, which equals `albumOnAccent` (`features/family/manage_families_page.dart:274,471`, `add_co_owner_dialog.dart:276`, `start_family_dialog.dart:255`)
    - `Color(0xFFFFF7F5)` (`manage_families_page.dart:724`)
    - `Colors.white` (`features/comments/comment_composer.dart:118`, `features/places/place_picker_modal.dart:392`, `features/settings/settings_page.dart:889`)
    - `albumWhite` (`ui/dialogs/family_blur_dialog.dart:187`)
    - private `_inviteOnPrimary` / `_landingOnPrimary` (`features/auth/invite_sign_in_page.dart:446`, `sign_in_page.dart:463`)
  - **Disabled fills use three alphas:** 0.55 (`sign_in_code_form.dart:131`), 0.4 (`invite_modal.dart:885`, `leave_story_dialog.dart:124`) and 0.35 (`add_person_modal.dart:409`, `place_picker_modal.dart:396`).
  - **One override sets its own fill,** `Color(0xFF6B5B55)` (`start_family_dialog.dart:255-260`).
  - **Live:** the disabled "Create family" (`start-family-dialog-1280x800.png`) is greyed terracotta, while the disabled "Publish perspective" (`add-perspective-1280x800.png`) is flat grey.
- **Recommendation:** `FButton(variant: FButtonVariant.primary)` themed once by `albumForuiTheme()` (`albumTerracotta`/`albumOnAccent`, pill). Delete every per-site `styleFrom`.

### UX-02 (high): Seven segmented-control implementations
- **Screens:** timeline, tree, all stories, invite, place picker, settings.
- **Evidence:**
  1. `ViewSwitch` wraps a Material `SegmentedButton` (`ui/timeline/view_switch.dart:51`), styled by `segmentedButtonTheme` (`core/theme/album_theme.dart:375`). The comment at `:373-374` still claims "only the timeline's ViewSwitch uses SegmentedButton".
  2. `_ZoomSwitch` (`features/timeline/zoom_switch.dart:10-204`) is three `TextButton`s over a sliding terracotta pill (`AnimationController` at `:54`, pill key at `:164`). It sits in an 8 px-corner box (`:140`), which clashes with the pill inside.
  3. A raw `SegmentedButton<FamilyTreeView>` at `features/timeline/tree/family_tree_page.dart:214`.
  4. A hand-copied `ViewSwitch` row in `tree_graph_view.dart:167-176`.
  5. All-stories `_GroupBySwitch` (`features/all_stories/all_stories_page.dart:887-1033`): its own animated pill, measured with GlobalKeys.
  6. Invite tabs (`features/invites/invite_modal.dart:410-458`): r12 box with r8 `Material` tabs.
  7. Place-picker tabs (`features/places/place_picker_modal.dart:428`, filled terracotta tab) and settings tabs (`settings_page.dart:522`, underline) plus birth-visibility pills (`:762`).
- **Live:** `timeline-decades-1280x800.png` (boxed pill), `family-tree-overview-1280x800.png` (two Material segmented buttons side by side), `all-stories-1280x800.png`, `invite-modal-1280x800.png`, `place-picker-1280x800.png`, `settings-1280x800.png`.
- **Recommendation:** one `ViewSwitch<T>` with `FTappable` segments and a sliding `albumTerracotta` pill on an `albumPillFill` track with an `albumSageLine` stadium border. Use it for every "pick one view" control. Settings section tabs may become `FTabs`.

### UX-03 (med): The page title has five sizes
- **Evidence:** all are Newsreader for the same "page title" role:
  - "Stories" 40 w500 (`all_stories_page.dart:296-306`)
  - "Manage families" 48 w400 (`manage_families_page.dart:254-262`, again at `:504`)
  - family name 36 w700 (`manage_family_page.dart:470-479`)
  - "Settings" 36 w700 (`settings_page.dart:395-403`)
  - reader story title `headlineMedium` overridden to 36 (`story_reader_page.dart:958-966`)
  - tree title `TreeHeading` 32 w500 (`timeline/tree/treemap_view.dart:222-231`)
  - family-landing section "Latest" 32 (`family_landing_page.dart:456-458`)
- **Live:** compare `manage-families-1280x800.png`, `settings-1280x800.png` and `all-stories-1280x800.png`.
- **Recommendation:** page title = `textTheme.headlineLarge` (forui `typography.xl3` via `albumForuiTheme()`), section title = `headlineSmall`, with no `fontSize:` at call sites.

### UX-04 (med): Typography drift through direct `GoogleFonts` sizes
- **Evidence:** 251 `GoogleFonts.*(` calls in `lib/` and 21 distinct literal `fontSize:` values: 9, 10, 11, 12, 13, 14, 14.5, 15, 16, 18, 20, 22, 24, 26, 28, 30, 32, 36, 40, 48 and 52.
  - The most common are 14 (96 sites), 12 (48) and 16 (26).
  - The heaviest files are `manage_family_page`, `manage_families_page`, `album_header`, `invite_modal` and `sign_in_page`.
- **Recommendation:** route all text through `Theme.of(context).textTheme` / `context.theme.typography` from `albumForuiTheme()`. Add an architecture test that bans `fontSize:` outside `core/theme/`, with a shrinking skip list like the colour one.

### UX-05 (med): Colour skip list
- **Evidence:** `test/architecture/no_hardcoded_colors_test.dart:5-22` exempts 16 files, with the ceiling at `:25`. The list:
  - `invite_sign_in_page`, `comment_composer`, `drafts_page`
  - `add_co_owner_dialog`, `manage_families_page`, `manage_family_page`, `start_family_dialog`, `start_timeline_dialog`
  - `invite_modal`, `add_perspective_page`, `place_picker_modal`, `search_page`, `settings_page`
  - `new_story_page`, `photo_strip`, `story_reader_page`
- **Example:** the reader's timeframe/place pill uses `Color(0xFFF3EDE6)` (`story_reader_page.dart:1325`).
- **Recommendation:** each `## Work breakdown` slice removes its files from the list and lowers `_skipListCeiling`. Map literals to `album*` tokens, or propose a new token to the owner.

### UX-06 (med): Theme radii contradict the token docs; `AlbumFieldBorder` is unused
- **Evidence:** the `AlbumRadius` docs (`core/theme/album_theme.dart:78-99`) say small tappable controls are pills and that fields use `card` (12). The theme says otherwise:
  - chips r8 (`:322`)
  - filled and outlined buttons r8 (`:330`, `:346`)
  - inputs `OutlineInputBorder` r8 (`:358-359`)
  - dialogs circular r16 (`:352`)
- `albumCardRadius = 12.0` (`:46`) duplicates `AlbumRadius.card`.
- `AlbumFieldBorder` (`:116`) appears only in `test/core/theme/album_field_border_test.dart`; nothing in `lib/` uses it.
- `BorderRadius.circular(` appears 157 times, 13 of them `circular(999)`.
- **Recommendation:** pills via `albumForuiTheme()` button styles. Use `FTextField` with the `card` radius, or adopt `AlbumFieldBorder` in `inputDecorationTheme` for unmigrated screens. Replace `albumCardRadius` with `AlbumRadius.card`. Radii come from `AlbumRadius`, and `circular(999)` becomes `StadiumBorder`.

### UX-07 (low): Header keys don't match their labels
- **Evidence:** in `ui/album/album_header.dart`:
  - `Key('timeline-nav')` (`:348`) and `header-underline-timeline` (`:351`) sit on the **Stories** item (`:349`).
  - `header-underline-decades` (`:359`) sits on the **Timeline** item (`:356-357`).
  - The callbacks are swapped the same way: `onTimeline` opens All Stories and `onDecades` opens the timeline (`:128-129`).
- **Recommendation:** keys `header-nav-stories`, `header-underline-stories` and `header-underline-timeline`; callbacks `onStories`/`onTimeline`.

### UX-08 (high): Family switch always goes to `/family`
- **Evidence:** `_FamilyMenu._pickFamily` (`ui/album/album_header.dart:691-699`) calls `go(AppRoutes.familyLanding)` from every page except the landing. Switching family on the timeline, tree or all-stories throws away the view the user was in.
- **Recommendation:** keep the view. The timeline reloads in place; the tree and all-stories pages go to the same route for the new family. Picking the current family does nothing.

### UX-09 (high): No way from the timeline to the tree except a menu
- **Evidence:** the only caller of `AppRoutes.familyTreePath` (`core/router/app_routes.dart:30`) is the family menu's "See the whole family tree" (`ui/album/album_header.dart:754`, `:811`). The timeline has no control for it (`timeline-decades-1280x800.png`).
- **Recommendation:** an `FButton(variant: ghost)` "Family tree" (existing copy) beside Filters in the timeline subheader.

### UX-10 (med): Empty, loading and error states are inconsistent
- **Evidence:**
  - **Timeline empty:** a bare default-style `Text` with no action (`features/timeline/timeline_page.dart:828-836`, `timeline-nofamily-*.png`). Load errors only clear flags (`:216`, `:404`), so a failure looks identical to "no stories".
  - **Timeline filter-empty** uses `EmptyTimeline` in a card (`:797-818`).
  - **Tree error:** a `Wrap` with error-coloured text and a terracotta `TextButton` "Retry" (`timeline/tree/family_tree_page.dart:244-271`, `family-tree-error-1280x800.png`). Tree empty uses `EmptyTimeline` (`tree_graph_view.dart:165`, `treemap_view.dart:86`).
  - **All stories:** the error is a `Row` with a retry (`all_stories_page.dart:542-577`); the empty state is a bare `Text` (`:579-591`).
  - **Drafts:** loading, error and empty are all bare centred `Text`, and the error has **no retry** (`drafts/drafts_page.dart:298-323`).
  - **Search:** errors are a SnackBar (`search_page.dart:117-121`).
  - **Place picker:** map failure is `Text` plus `TextButton` (`place_picker_modal.dart:749-752`).
  - **Manage families:** empty shows a title and button only (`manage-families-empty-1280x800.png`).
- **Recommendation:** one `EmptyTimeline`-style shared empty/error widget (message, optional action as `FButton` ghost or primary) in `lib/ui/`, used for every list surface. Loading uses `FProgress`/skeleton.

### UX-11 (high): First run with no family is a dead end
- **Screen:** `/timeline` for a new account.
- **Evidence:**
  - With no family, `appStartPath` (`app/app_router.dart:59-72`) sends the user to the timeline.
  - The timeline says "No stories yet. Capture the first one for this family." (`timeline_page.dart:832`) when no family exists, and offers no action.
  - Home does nothing, and the header shows no "New story".
  - The only route to "Start a family" is Family menu → Manage families → Start a family (`timeline-nofamily-1280x800.png`, `family-menu-nofamily-1280x800.png`, `manage-families-empty-*.png`).
- **Recommendation:** route the no-family state to a start screen whose primary `FButton` opens `showStartFamilyDialog`. This needs owner-approved copy, so it is not in this run.

### UX-12 (med): Start-family copy promises the wrong destination
- **Evidence:** the dialog says "You'll land on this family's empty timeline after create." (`features/family/start_family_dialog.dart:210`), but `_start` goes to `/family` (`manage_families_page.dart:179`). See `start-family-dialog-1280x800.png`, then `family-landing-empty-1280x800.png`.
- **Recommendation:** align the copy or the route; the owner chooses which.

### UX-13 (high): Adding a person before the first save fails
- **Screen:** capture.
- **Evidence:**
  - On a fresh `/stories/new`, typing title, body and year, then Add person → pick → Add person, fails. `story/linkPerson` returns 400 `forbidden` ("You don't have access to that.").
  - The cause: `_scheduleAutosave` mints a client `_storyId` (`features/stories/new_story_page.dart:209`) before any draft exists, and `AddPersonModal` links immediately with that id (`:425-436`, `features/people/add_person_modal.dart:243-256`).
  - The SnackBar renders **under** the modal scrim, so the user sees nothing happen.
  - "Save draft" first, then add, works (that is how the seed stories were published).
- **Recommendation:** create or await the draft before linking. Show modal-scoped errors inside the dialog (inline error, or `FToast` above the barrier). This is a behaviour bug, so it goes to the stories slice.

### UX-14 (med): Capture validation is a bare outline
- **Evidence:** on a failed publish, missing sections get a terracotta outline drawn outside the card (a double frame). The only message, "Finish the highlighted fields to publish." (`new_story_page.dart:942`), sits at the top of the form, off-screen when the user is at the fields. There is no per-field text. See `story-capture-validation-1280x800.png` and `_highlightIfMissing` (`:1330`).
- **Recommendation:** an `FCard` section with an error border token, plus forui field `error:` text per section.

### UX-15 (high): The header collapses badly in iPad portrait
- **Evidence:** at 744 pt the wordmark ellipsizes to "Tell …" and the family name disappears, leaving only a chevron (`timeline-decades-744x1133.png`, `manage-families-empty-744x1133.png`). The wordmark ellipsis is at `ui/album/album_header.dart:634-636` and the family label at `:733`.
- **Recommendation:** below `AlbumBreakpoint.sidebar`, use a compact header: a short wordmark, the family name kept (it is the context for every screen), and the nav moved into an `FPopover` menu. The header slice.

### UX-16 (low): Three wordmarks
- **Evidence:** the header uses italic Newsreader (`album_header.dart:634`). Sign-in uses bold upright (`features/auth/sign_in_page.dart:197`, `sign-in-1280x800.png`), as does add-perspective (`add-perspective-1280x800.png`). Search draws its own (`search_page.dart:369`).
- **Recommendation:** one `AlbumWordmark` widget in `lib/ui/album/`.

### UX-17 (med): Screens outside the album chrome
- **Evidence:**
  - Search has its own top bar with a text "Close" (`search_page.dart:369`, `search-1280x800.png`).
  - Add-perspective is a full page with its own wordmark and no column (`add-perspective-1280x800.png`). Capture and reader, by contrast, are modals.
- **Recommendation:** perspective becomes a modal like capture (`albumModalPage`). Search keeps a full-screen layout but uses the shared wordmark and an `FButton` ghost close.

### UX-18 (med): "New story is the only filled terracotta button" is broken
- **Evidence:** the R2 header decision (uxd-handoff "Locked UX decisions") is contradicted by filled terracotta on:
  - reader "Add perspective" and "Add comment", in two different sizes (`story-reader-1280x800.png`)
  - drafts "Continue writing" (`drafts-1280x800.png`)
  - "Start a family" (`manage-families-1280x800.png`)
  - the selected place-picker and invite tabs
- **Recommendation:** use `FButton` outline or secondary for in-page secondary actions. Reserve primary for the single main action per surface (New story in the header, the submit button in dialogs).

### UX-19 (med): Six chip styles
- **Evidence:**
  - Timeline filter `FilterChip` r8 (`features/timeline/filter/filter_panel.dart:105`, `:121`, `_ChipLabel` `:202`, `timeline-filters-1280x800.png`)
  - drafts `FilterChip` with a sage check (`drafts/drafts_page.dart:355`)
  - start-timeline `FilterChip` (`start_timeline_dialog.dart:450`)
  - search `_FilterChip` (`search_page.dart:690`) and filled-terracotta person chips in results (`search-results-1280x800.png`)
  - Days-card `_FullChip` (`features/timeline/rails/full_card_rail.dart:961`)
  - all-stories "Members"/"Started a timeline" pills (`all-stories-1280x800.png`)
- **Recommendation:** `AlbumChip` (stadium; `albumSageTint` selected / `albumBlushPale` otherwise; `albumSageLine` border; 44 pt when tappable) for all of them.

### UX-20 (med): Four dialog helpers and different dialog surfaces
- **Evidence:**
  - **Helpers:**
    - `showBlurredCard` (`ui/dialogs/family_blur_dialog.dart:17`, 7 calls)
    - `showAlbumDialog` (`ui/album/album_chrome.dart:199`, 7 calls)
    - direct `showGeneralDialog` (6 calls: `add_co_owner_dialog:17`, `start_family_dialog:15`, `start_timeline_dialog:37`, `family_blur_dialog:58,238`, `leave_story_dialog:28`)
    - `showDialog` + `AlertDialog` (`family_landing_page.dart:250`, `:580`)
  - **Live:** the start-timeline dialog uses a blush surface with a full-width outline Cancel (`start-timeline-dialog-1280x800.png`). Start-family, add-person and place-picker use parchment with right-aligned buttons.
- **Recommendation:** one `showAlbumDialog` built on `FDialog` (surface `albumMenuSurface`, barrier `albumModalScrim`, actions right-aligned: ghost Cancel + primary).

### UX-21 (med): Family tree page layout
- **Evidence:**
  - The title and graph hug the left edge, not the album column. The graph uses a small top-left area of a 1280 canvas.
  - The title reads "The Morgan Family family tree".
  - The treemap shows two segmented controls side by side, plus a Material checkbox legend.
  - No header nav item is active.
  - See `family-tree-graph-1280x800.png` and `family-tree-overview-*.png`; the title is at `treemap_view.dart:222-231`.
- **Recommendation:** centre in `AlbumColumn`, render the title with `headlineLarge`, and use `ViewSwitch` for both switches. Wording changes need owner copy.

### UX-22 (low): Header active state is inconsistent
- **Evidence:**
  - Home shows active as a terracotta icon with no underline (`family-landing-1280x800.png`).
  - Tree and manage pages underline the family name instead of a nav item (`manage-families-1280x800.png`).
  - While families load, the header shows the placeholder "Family" (`drafts-*`, `family-tree-error-1280x800.png`).
  - A grey Material tooltip "Family" appears under the menu (`manage-families-empty-1280x800.png`).
- **Recommendation:** one active-underline rule, a blank or skeleton name while loading, and `FTooltip` styled by the album theme.

### UX-23 (low): Photo-less layouts keep empty photo slots
- **Evidence:** all-stories cards keep a blank image area about 120 px tall (`all-stories-1280x800.png`). Person-profile rows keep an empty thumbnail gutter (`person-profile-1280x800.png`).
- **Recommendation:** collapse the slot when there is no photo, or fill it with an `albumWatermark` year placeholder.

### UX-24 (low): The reader's place chip uses a calendar icon
- **Evidence:** the place is rendered through `_timeframePill` (`features/stories/story_reader_page.dart:1204`, `:1322-1333`, `Icons.calendar_today`). See `story-reader-1280x800.png` ("The farm" next to a calendar).
- **Recommendation:** a place pill with `Icons.place_outlined`, built on `AlbumChip`.

### UX-25 (low): Author and count copy
- **Evidence:**
  - Authors show as "Member" when the profile name is empty (`data/comments_api.dart:8`, `data/perspectives_api.dart:8`), even when a person record named "david" exists (`story-reader-1280x800.png`, `timeline-days-1280x800.png`).
  - "1 members" (`manage_families_page.dart:633`, `manage-families-1280x800.png`).
  - The focused decade reads "2 stories preserved" while the others read "1 story" (`timeline-decades-1280x800.png`).
- **Recommendation:** owner copy pass; pluralise counts.

### UX-26 (med): The place picker without Mapbox is misleading
- **Evidence:** with no token, the picker says "Couldn't load the map. Check your connection and try again." (`place_picker_modal.dart:749-752`). The All Places search silently returns nothing (`place-picker-1280x800.png`). A place is required to publish, so a token-less environment can't publish through the UI at all.
- **Recommendation:** a distinct "place search is off" state using the shared empty widget. [INFERENCE] Production sets the token (`justfile` `deploy-web`), so this mainly hits dev and preview builds.

### UX-27 (med): Oversized files
- **Evidence:** at 32ad96e:
  - The three named: `ui/album/album_header.dart` (1187 lines), `features/timeline/rails/full_card_rail.dart` (1115), `features/timeline/timeline_page.dart` (911).
  - Also over 900: `story_reader_page.dart` 1603, `new_story_page.dart` 1438, `manage_family_page.dart` 1275, `all_stories_page.dart` 1047, `timeline_branching.dart` 988, `search_page.dart` 976, `settings_page.dart` 948, `invite_modal.dart` 946, `add_person_modal.dart` 925.
- **Recommendation:** split as each slice migrates. The header's family menu and nav become their own files under `lib/ui/album/`.

### UX-28 (med): iPad F15, narrow portrait cards
- **Evidence:** F15 in `2026-11-07-timeline-lab-ipad-review.md` (superpowers plans) is "Cards use less than half the portrait width".
  - In the product app the Days rail uses literal breakpoints (`full_card_rail.dart:124`, `maxWidth >= 800`; `:126`, gap 32 below 720 else 80) instead of `AlbumBreakpoint`.
  - At 744 pt the cards go single-column and full-width (`timeline-days-744x1133.png`).
- **Recommendation:** wide when `maxWidth >= AlbumBreakpoint.sidebar`; gaps from `AlbumSpace`.

### UX-29 (low): iPad F16, the device checklist is still open
- **Evidence:** F16 ("Frame cost on iPad-class hardware is unknown", same doc) is unmeasured. Everything in this review is desktop Chromium at iPad viewport sizes, not a device.
- **Recommendation:** an owner-run device checklist on a real iPad: Safari, portrait and landscape, rail scroll frame cost, 44 pt targets, keyboard over the capture modal. Attach owner screenshots at 1280×800 and 744×1133 before merge (Phase 7 convention).

### UX-30 (low, record only): Duplicated callout render objects
- **Evidence:** `_RenderHangParentCallout` (`features/timeline/rails/mid_rail.dart:592`) and `_RenderDaysAttachedCallout` (`full_card_rail.dart:333`) duplicate the branch-callout layout.
- **Recommendation:** merge in a dedicated render-object slice with golden coverage. Not part of any UI slice.

### UX-31 (med): Rail secondary text has no token
- **Evidence:** the forui migration found that `albumDimInk` is reserved in the rails for filter non-matches (test "with the filter empty no text uses the dim ink"). Rail secondary text therefore still uses `albumInk` alphas from 0.45 to 0.7.
- **Recommendation:** an owner-approved token, e.g. `albumSoftInk`, for secondary rail text, distinct from `albumDimInk`.

### UX-32 (low): No elevation token
- **Evidence:** `albumShadow` (`core/theme/album_theme.dart:41`) is raw black "use with withAlpha". Card shadows across the rails use `albumInk` at 0.04/0.08 alphas.
- **Recommendation:** owner-approved shadow tokens (colour + alpha + blur) for card and focused card, also consumed by `albumForuiTheme()`.

## Done in this run

Branch `chore/context-forui-timeline`: commits `8f23984` (forui foundation, album theme, nav fixes) and `416231f` (timeline and tree migration).

- **UX-07:** header keys and callbacks renamed to match their labels (`header-nav-stories`, `header-underline-stories`, `header-underline-timeline`; `onStories`/`onTimeline`).
- **UX-08:** the family switch keeps the view: the timeline reloads in place, the tree goes to `/family/<new>/tree` and all-stories to `/family/<new>/stories`. Picking the current family is a no-op.
- **UX-09:** the timeline subheader gained a ghost `FButton` "Family tree" (`Key('timeline-open-tree')`) to `/family/<id>/tree`.
- **UX-02 (timeline and tree part):** `ViewSwitch<T>` is now the single segmented control: `FTappable` segments, a sliding terracotta pill ported from `_ZoomSwitch`, semantics `selected`.
  - It replaces `_ZoomSwitch`, the tree's raw `SegmentedButton`, and the hand-copied row in `tree_graph_view`.
  - `segmentedButtonTheme` is removed from `albumTheme()`.
  - Still open: all-stories group-by, invite, place-picker and settings tabs.
- **UX-19 (timeline part):** new `AlbumChip` (`lib/ui/controls/album_chip.dart`) replaces the filter-panel `FilterChip`/`_ChipLabel` and the Days-card `_FullChip`. Deviation: `AlbumChip` gained a `dimmed` flag for filter non-matches.
- **UX-01 (timeline, tree and filter part):** Material buttons in the timeline host, rails, tree views, filter panel, `OriginBanner` and `EmptyTimeline` are now forui `FButton`.
  - Buttons are pill-shaped through `albumForuiTheme()`; no r12 fallback was needed.
- **UX-04 / UX-06 (timeline, tree and filter part):** alpha, radius, font-size and padding literals in `far_rail`, `mid_rail`, `full_card_rail`, `timeline_branching`, the tree views, the filter panel, `origin_banner` and `empty_timeline` mapped to `album*` tokens, `AlbumRadius` and `AlbumSpace`. Two deviations:
  - Rail secondary text keeps `albumInk` alphas 0.45–0.7 because `albumDimInk` is reserved for filter non-matches (new finding UX-31).
  - Card shadows keep `albumInk` 0.04/0.08 because no elevation token exists (new finding UX-32).
- **UX-28 (F15):** `full_card_rail` breakpoints use `AlbumBreakpoint.sidebar` and `AlbumSpace` gaps.
- **UX-10 (timeline and tree part):** the timeline's empty state and the tree's load error now use `EmptyTimeline` (tree: existing error text plus "Retry").
- **UX-03 (tree part):** tree titles use `textTheme.headlineLarge` instead of direct `GoogleFonts` sizes.
- **Foundation:** `albumForuiTheme()` / `albumAppBuilder` (`lib/core/theme/album_forui_theme.dart`) skin forui to the album tokens. `MaterialApp.router` wraps every route in `FTheme`; screens not yet migrated keep `albumTheme()` pixels.
  - Constraint for later slices: forui widgets need an `FTheme` ancestor, so every test harness that renders them needs `builder: albumAppBuilder`.

## Work breakdown

Every slice also removes its files from the colour skip list (`test/architecture/no_hardcoded_colors_test.dart`) and lowers `_skipListCeiling`, swaps Material buttons for `FButton`, and moves text to theme styles.

| # | Slice | Files | Findings | Status |
|---|---|---|---|---|
| 1 | header | `lib/ui/album/album_header.dart` (split), `album_chrome.dart` | UX-01, UX-15, UX-16, UX-18, UX-22, UX-27 | todo |
| 2 | all_stories | `lib/features/all_stories/all_stories_page.dart`, `all_stories_card.dart` | UX-02 (group-by → `ViewSwitch`), UX-03, UX-10, UX-19, UX-23, UX-27 | todo |
| 3 | stories (capture, reader) | `lib/features/stories/new_story_page.dart`, `story_reader_page.dart`, `reader_meta.dart`, `photo_strip.dart` | UX-01, UX-03, UX-05, UX-13, UX-14, UX-18, UX-24, UX-25, UX-27 | todo |
| 4 | family (landing, manage) | `lib/features/family/family_landing_page.dart`, `manage_families_page.dart`, `manage_family_page.dart`, `start_family_dialog.dart`, `start_timeline_dialog.dart`, `add_co_owner_dialog.dart`, `transfer_ownership_dialog.dart`, `delete_family_dialog.dart`, `lib/app/app_router.dart` (no-family start) | UX-01, UX-03, UX-05, UX-10, UX-11, UX-12, UX-18, UX-19, UX-25, UX-27 | todo |
| 5 | invites | `lib/features/invites/invite_modal.dart`, `invite_accept.dart`, `lib/features/auth/invite_sign_in_page.dart` | UX-01, UX-02 (tabs), UX-05, UX-27 | todo |
| 6 | people | `lib/features/people/person_profile_dialog.dart`, `add_person_modal.dart`, `edit_person_dialog.dart`, `person_date_field.dart` | UX-01, UX-13 (modal-scoped error), UX-23, UX-27 | todo |
| 7 | places | `lib/features/places/place_picker_modal.dart`, `place_map.dart` | UX-01, UX-02 (tabs), UX-05, UX-10, UX-26 | todo |
| 8 | search | `lib/features/search/search_page.dart`, `search_recents.dart` | UX-05, UX-10, UX-16, UX-17, UX-19, UX-27 | todo |
| 9 | settings | `lib/features/settings/settings_page.dart` | UX-01, UX-02 (tabs, visibility pills), UX-03, UX-05, UX-27 | todo |
| 10 | drafts | `lib/features/drafts/drafts_page.dart` | UX-05, UX-10 (retry), UX-18, UX-19 | todo |
| 11 | auth | `lib/features/auth/sign_in_page.dart`, `sign_in_code_form.dart` | UX-01, UX-04, UX-16 | todo |
| 12 | comments/perspectives | `lib/features/comments/comment_composer.dart`, `lib/features/perspectives/add_perspective_page.dart` | UX-01, UX-05, UX-17, UX-18 | todo |
| 13 | dialog consolidation | `lib/ui/dialogs/family_blur_dialog.dart` (`showBlurredCard`), `lib/ui/album/album_chrome.dart` (`showAlbumDialog`), every direct `showGeneralDialog`, `family_landing_page.dart` `AlertDialog` | UX-20, UX-01 | todo |
| 14 | tokens and rails follow-up | `lib/core/theme/album_theme.dart`, `album_forui_theme.dart`, `lib/features/timeline/rails/*`, `lib/features/timeline/tree/*` | UX-06 (`albumCardRadius`, `AlbumFieldBorder`, input radius), UX-21, UX-31, UX-32 (need owner-approved tokens and copy), UX-30 (record only) | todo |
| 15 | iPad device pass | none (owner checklist) | UX-29 | todo |

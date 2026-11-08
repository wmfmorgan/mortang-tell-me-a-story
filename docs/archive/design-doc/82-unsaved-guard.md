# #82 Unsaved-input guard: architecture lock rev 1. Status: LOCKED by Bill via Erlich 2026-10-22 6:44 AM CT ("#82 architecture rev 1: lock it"), 0 OPENs. Sources: UX rev 4 (PR #97), code facts unsaved-input-facts.md, main@5161164.

# #82 ARCHITECTURE LOCK rev 1 (LOCKED): family switch landing + unsaved-input guard

- Status: LOCKED (see line 1). OPEN-1..3 below are resolved in the Resolutions block at the end. This is a design, not code. UX authority: `docs/ux/82-family-switch.md` rev 4 (LOCKED). This doc changes no UX and adds no copy.
- Code read: `wmfmorgan/mortang-tell-me-a-story` main @ `51611641398ae0d442ff36b8dcd6dc564b223938`. Paths are under `apps/tell_me_a_story/lib/` unless stated. Facts: `unsaved-input-facts.md`.
- Baselines to hold: `flutter test` 504 passing, `flutter analyze` 27 issues (no new issues).

## 0. Constraints verified
- go_router is `^18.0.1` (`pubspec.yaml:38`), resolved 18.0.1 (`pubspec.lock:282-289`). `GoRoute.onExit` has existed since 10.2.0 with `(BuildContext, GoRouterState) -> FutureOr<bool>` since 14.0.0. In 18.0.1, `GoRouterDelegate` calls onExit on `go`/browser URL changes (`setNewRoutePath`, `_callOnExitStartsAt`) and on `pop` (`_handlePopPageWithRouteMatch`). The `context` it passes is the **root navigator context**, not the page context.
- onExit does **not** fire for `push`, because the page stays mounted. Drafts (`core/theme/album_header.dart:135-138`), Search (`:832`) and Settings (`:934-938`) all use push, so the header has to guard them itself.
- There is no state-management package (`pubspec.yaml:30-45`). The design uses `ChangeNotifier` and `InheritedNotifier` from the Flutter SDK only.
- `package:web` is transitive only (`pubspec.lock:951-958`). Importing it would add a `depend_on_referenced_packages` lint, so this design uses `dart:js_interop` (SDK) and changes no pubspec.
- No existing guard: there is no PopScope, onExit or beforeunload in lib (facts :14). Routes are flat GoRoutes with no shell (`core/router/app_router.dart:134-285`).

## 1. Dirty-state model (page-local)
A new `UnsavedGuard extends ChangeNotifier` is owned by each page's `State`. The page supplies three things:
- `bool Function() isDirty`, compared against a page-held **saved snapshot** (a plain immutable record).
- `Future<bool> Function() save`, which returns true only on success.
- `void Function() discard`, which restores the snapshot.

The page calls `guard.changed()` (that is, notifyListeners) from the setState sites that already exist. There is one flag, `exitPrompts`. When true (New/Edit story), every exit prompts. When false (Settings, Rename), only a family switch prompts (Rule 2 vs Rule 5).

| Surface | Snapshot fields | Dirty when | Snapshot (re)taken |
|---|---|---|---|
| New story / resumed draft (`features/stories/new_story_page.dart`) | `_title.text`, `_body.text`, `_year.text`, `_month`, `_day`, place id (`_selectedPlace?.id ?? _placeId`), selected person ids (`:90-127`) | `_autosaveDirty` (typed text pending in the 2 s debounce, or a failed "Not saved" retry, `:196, :236`) OR `_autosaveCoalesce` OR year/month/day/place/person-id set differs from the snapshot. This covers the facts' gap that autosave ignores date, place and removals (`:449-484`). A brand-new empty form snapshots as empty, so date-only or place-only input counts as dirty. | At the end of `initState` for a new story. At the end of `_hydrateDraft` (`:270-376`). After a successful autosave, using the values captured before the await (`:216-220`), not live fields. After a successful Save draft (`:703-708`). |
| Edit story (same page, `_editing`, `:138`) | the same fields, plus nothing autosaves (`:194, :208`) | any field differs from the snapshot | At the end of `_hydrateDraft`, and after Save changes succeeds |
| Settings (`features/settings/settings_page.dart`) | the existing `_loaded*` fields (`:65-70`, `_rememberLoaded` `:187-194`) | name, email or about text, `_storedBirth(_birth)` (date, precision; `:844`), `_visibility`, or `_pending != null` differs from the `_loaded*` fields | the existing `_rememberLoaded()` calls. **Fix:** move the `:262` call after the email reset at `:264-271`. Otherwise a saved email change leaves `_email.text != _loadedEmail` and the form reads as dirty. |
| Manage family detail (`features/family/manage_family_page.dart`) | `_detail.name` (`:112-114`) | `_canAdmin && _detail != null && _name.text != _detail!.name` | implicit: `_load()` already resets `_name` (`:112`) |

Photos are left out of the snapshot. **Assumption:** photo adds persist on add, so they are not "typing that would be lost". Add-person adds are written on link (`:425`) and also schedule an autosave (`:414`), so they are covered by `_autosaveDirty`.

## 2. Reusable guard: `lib/core/navigation/unsaved_guard.dart` (new)
- `class UnsavedGuard extends ChangeNotifier` contains `isDirty`, `exitPrompts`, `save`, `discard`, `skipNextPrompt()` (one-shot, see §4) and `Future<bool> confirmLeave(BuildContext, {String? switchToFamilyName})`. It returns true when the caller may proceed.
  - Re-entrancy: while a prompt is open, a second `confirmLeave` returns false (Stay). That makes a double prompt structurally impossible.
  - Clean: it returns true at once and shows no dialog.
  - Stay: false. Discard: calls `discard()`, then true.
  - Save: awaits `save()`. Success returns true; failure returns false (the page shows its own error).
- `class UnsavedGuardScope extends InheritedNotifier<UnsavedGuard>`. Pages wrap their `Scaffold` in it. `AlbumHeader` sits inside the Scaffold's appBar, so `UnsavedGuardScope.maybeOf(context)` finds it from the header (`album_header.dart:21-143`).
- `abstract final class UnsavedGuards` is a static registry keyed by `GoRouterState.pageKey`. A page registers in `didChangeDependencies` and unregisters in `dispose`. `UnsavedGuards.onExit(context, state)` is the shared `ExitCallback`: it looks up `state.pageKey` and returns `guard?.confirmLeave(context) ?? true`. `anyExitDirty` feeds beforeunload.
- Dialog: `lib/core/navigation/leave_story_dialog.dart` (new), `showLeaveStoryDialog(...)`.
  - Reuses `familyBlurShell` (`features/family/family_blur_dialog.dart:9-14`) and the `_FamilyBlurDialog` card styling (#FFF8F6, Newsreader title, Literata body, X; `:106-215`).
  - It cannot reuse `showFamilyBlurDialog` (`:47-81`): that dialog has 2 buttons and its scrim always pops (`:108`).
  - It is a `StatefulWidget` on `showGeneralDialog(barrierDismissible: false)`. The widget handles outside taps, X, and Esc (`CallbackShortcuts` + autofocus `Focus`) itself, all mapped to Stay, and ignores them while `_saving`. `PopScope(canPop: !_saving)` blocks system back during a save.
  - The dialog runs `save()` itself. That way it can disable all 3 buttons while the save runs, then pop with stay/proceed.
  - Copy is exactly as in the UX note. The title is "Leave this story?". With a family name the body is the full mock sentence pair, and without one it is the first sentence only. Buttons are Stay, Discard, Save.
- Registration per surface:
  - New/Edit story: `exitPrompts: true`, `save` = §4. Its routes get `onExit: UnsavedGuards.onExit` (`app_router.dart:148-163, 173-185`).
  - Settings and Manage detail: `exitPrompts: false`, `save` = `_save` / `_rename` changed to return `bool` (`settings_page.dart:228-289`, `manage_family_page.dart:134-143`). They get **no** onExit, because their other exits must not prompt (UX :66).

## 3. Interception points (each exit has exactly one prompt site)
| Exit | Mechanism | Prompt site |
|---|---|---|
| Family row, different family (`album_header.dart:640-641`), all header pages | `_FamilyMenu.onSelected`: (1) if `value == currentFamilyId`, return (Rule 3, §5). (2) `await guard?.confirmLeave(ctx, switchToFamilyName: name)`; on false, return. This runs before `onSelected`, so on Stay the session family is never changed. (3) `onSelected(value)` (remember). (4) `go('/timeline')` unless `page == timeline`. `_FamilyMenu` gains a `page` param and the `/manage-families` path check at `:590-599` is replaced. | header (guard has no prompt left: after Save or Discard the page is clean, so onExit returns true) |
| Start a family (`:601-609`) | dialog → id → `confirmLeave` (exitPrompts guards only) → `remember` → `go`. See OPEN-2. | header |
| Manage families (`:636-638`), Timeline nav (`:130-133`), Settings "Back to Timeline" (`settings_page.dart:398`) | `go` → onExit | onExit (story routes only) |
| Drafts (`:135-138`), Search chip (`:832`), avatar → Settings (`:934-938`) | `push`, so no onExit. On an exitPrompts guard, `confirmLeave` runs before the push. Discard has reverted the editor and Save has saved it, so the editor stays mounted underneath in a clean state. | header |
| Logout (`:912-919, 940`) | On an exitPrompts guard, `confirmLeave` runs, and the callback/`signOut` happens only after it returns true. Ordering: Save → await → signOut. The redirect to `/` (`app_router.dart:113-115`) then fires onExit on a clean page. This also fixes facts (c): the flush racing sign-out. | header |
| Edit Cancel (`new_story_page.dart:747-750` → `_returnToReader` `:736-745`, `context.pop`/`go`) | pop → `_handlePopPageWithRouteMatch` → onExit; or go → onExit. No change to Cancel itself. | onExit |
| System back (Android), iOS swipe-back | `PopScope(canPop: !guard.isDirty, onPopInvokedWithResult: (didPop, _) { if (!didPop) ... })` on the story pages, rebuilt through a `ListenableBuilder` on the guard. With `didPop == false`, it awaits `confirmLeave`, and on true calls `GoRouter.of(context).pop()` in the next frame, where onExit finds the page clean. `canPop:false` also disables the iOS swipe gesture, so the page can't animate out before the prompt. | PopScope |
| Browser back/forward (web) | URL change → `setNewRoutePath` → onExit | onExit |
| Tab close, refresh (web) | see below | browser |

- **Signed-out redirect:** when `!authRefresh.isSignedIn`, the onExit closure returns true without prompting. It is built inside `createAppRouter`, which has `authRefresh` (`app_router.dart:78-79`). The Logout path has already prompted, and a session that expired cannot save anyway (Risk R4).
- **beforeunload:** add `lib/core/navigation/before_unload.dart`, which exports `before_unload_stub.dart` `if (dart.library.js_interop) 'before_unload_web.dart'`.
  - The web file uses `@JS()` extension types on `window`. Its `beforeunload` listener calls `event.preventDefault()` and sets `returnValue = ''` only while `UnsavedGuards.anyExitDirty` is true. Settings and Rename guards are excluded (UX :76 is Rule 5 only). There is no custom text, so the browser shows its generic warning.
  - `installBeforeUnloadGuard()` is called once in `main()` after `configureUrlStrategy()` (`main.dart:18`). The stub is a no-op, so iOS, Android and the VM tests compile.
  - The repo's existing pattern is `dart.library.html` (`main.dart:7-8`). `js_interop` is chosen here because it is also true under wasm. **Assumption:** the web build may move to wasm; if not, `html` would also work.
- No double prompt:
  - The header prompts only for exits that onExit can't see (push, sign-out, family switch, Start a family).
  - onExit prompts for go, pop and browser exits.
  - PopScope prompts only when the pop was blocked.
  - After any proceed the page is clean, so a downstream onExit returns true.
  - The re-entrancy lock covers whatever is left.

## 4. Save-from-prompt semantics
- New story `save` = a refactor of `_onSaveDraft` (`:698-717`) into `Future<bool> _saveDraftCore()`. It keeps the `_canSaveDraft` check, the same `_persistDraft()`, the same "Draft saved" and "Couldn’t save draft. Try again." snackbars, and the same `_busy` state. The button calls it and ignores the bool. Behavior is unchanged except for the re-snapshot.
- Edit story `save` = `Future<bool> _saveChangesCore()`, split from `_onSaveChanges` (`:752-768`). The core does **not** call `_returnToReader(true)`. The button calls the core, then `skipNextPrompt()` and `_returnToReader(true)`. From the prompt, a successful save finishes the original exit (UX :56, :80).
- Settings `save` = `_save` returning bool. It returns false on empty name (`:231`), the about >500 snackbar (`:232-236`), and the catch snackbar (`:274-285`). Rename `save` = `_rename` returning bool. It returns false on the `ManageFamiliesException` snack (`:140-142`), and the guard catches any other throw as false.
- Failure: the dialog closes and the user stays on the page, which shows its own error (if any). Nothing navigates.
- **Rule 4 / family label gap** (facts :61, `new_story_page.dart:835-840`):
  - Delete `_menuFamilyId`. The header shows `_familyId`, the family the story belongs to (UX :62).
  - `_selectFamily` becomes `FamilySelection.remember(id)` only, because the header navigates afterwards.
  - Save from the prompt runs **before** `remember`, and `_persistDraft` uses `_ensureFamilyId()` → `_familyId` (`:378-385, :602`). So the write stays in the original `family_id`.
  - The dispose flush also reads `_familyId`, so it stays in the original family too.
  - Nothing ever reassigns `_familyId` from the session after bootstrap or hydrate (`:254, :294`).
- Debounce after dispose (facts :166):
  - Discard runs `_autosaveTimer?.cancel()`, sets `_autosaveDirty = _autosaveCoalesce = false`, and restores the snapshot into the controllers and fields. The dispose flush (`:182-186`) then has nothing to send, so discarded text is never written.
  - Save cancels the timer as `_onSaveDraft` already does (`:700`).
  - Add `_disposed = true` at the top of `dispose()`. The coalesced re-run in `_runAutosave`'s `finally` (`:242-246`) is skipped when disposed, so disposed controllers are never read.
  - The clean-exit flush stays as today (UX :39, :61), but reads only the values captured at `:216-220`.
- Publish (`:770-803`), Save draft and Save changes never prompt. Publish calls `skipNextPrompt()` before its `go`. Save draft stays on the page and re-snapshots. Its `_clearNewTimelineFrom` `go` (`:719-734`) keeps the same path and pageKey. **Assumption:** onExit does not fire there; it would return true anyway, since the page is clean.
- `NewStoryPage` gets an `onLogout` param passed from the router (it passes none today, `app_router.dart:148-185`; header falls back at `album_header.dart:918`). This is for test injection only, with no behavior change.

## 5. Rule 3 no-op
- In `_FamilyMenu.onSelected`, `if (value == currentFamilyId) return;` runs before anything else. So there is no `onSelected`, no `remember`, no reload and no prompt.
- This replaces the per-page early returns, which ran *after* `remember` (`features/drafts/drafts_page.dart:147-152`, `features/timeline/timeline_page.dart:356-358`).
- On story pages `currentFamilyId` becomes `_familyId` (`new_story_page.dart:858`). Picking the session family when it differs from the story's family therefore counts as a switch. That is consistent with UX :62.

## 6. Data / API impact
None. There are no schema, migration, RLS, RPC or Edge Function changes.
- Saves reuse the existing calls: `StoriesApi.createDraft`/`updateDraft`/`autosaveDraft` (`data/stories_api.dart:437-509`), `ProfileApi.saveAccount`/`saveAvatar`/`updateEmail`, and `ManageFamiliesApi.renameFamily`.
- `family_id` is never changed on an existing row.
- `FamilySelection` stays in process memory (`data/family_selection.dart:1-10`).

## 7. Test plan
New widget tests with fake gateways (the existing `*Gateway` injection, `app_router.dart:78-95`) and a test `GoRouter`:
1. `unsaved_guard_test.dart`:
   - clean → proceed with no dialog
   - Stay, X, scrim tap and Esc → false
   - Discard → `discard()` called, true
   - Save ok → true; Save fails or returns false → false, still on page
   - while saving, all buttons and the scrim are inert
   - re-entrant call → false
2. `leave_story_dialog_test.dart`: exact title, both body variants and labels; button order right-aligned; stacked Save/Discard/Stay under the phone breakpoint (OPEN-3).
3. `album_header_family_switch_test.dart`:
   - Rule 1: `go('/timeline')` from Drafts, Settings, New, Edit and Manage; Timeline stays in place
   - related-family rows behave the same
   - Rule 3: current family → no `onSelected`, no navigation, `FamilySelection.id` unchanged
4. `new_story_guard_test.dart`:
   - prompt shown for year, month, day, place, person removal, a brand-new date-only form, and typing inside 2 s (`tester.pump` < `kAutosavePause`)
   - NOT shown after "Saved" (pump past 2 s + fake autosave ok)
   - each exit: Timeline, Drafts, Search, Settings, Start a family, Manage families, family switch, `handlePopRoute` (system back), router pop
   - Discard → fake API records no write after dispose
   - Save → `createDraft`/`updateDraft` with the **original** familyId after the switch, then lands on `/timeline`
   - Save failure → stays, "Couldn’t save draft. Try again." shown
   - Publish/Save draft → no prompt
5. `edit_story_guard_test.dart`: any field change prompts; Cancel and back prompt; Save changes button → no prompt and returns to reader; Save from prompt → finishes the exit, not the reader.
6. `settings_guard_test.dart`: dirty + family switch → prompt; dirty + Back to Timeline, Drafts or Logout → no prompt; clean after a saved email change (the `:262` fix).
7. `manage_family_rename_guard_test.dart`: rename differs + family switch → prompt; Rename fails → stays with the snack.
8. `logout_ordering_test.dart`: dirty New story → Logout → Save → spy order is `[updateDraft|createDraft, onLogout]`; Stay → no sign-out.

Then run the full suite. The result must be ≥ 504 + new tests passing, with analyze still at 27.

Manual check, Chrome web build plus an iPad (or simulator):
- refresh and tab close while dirty → generic warning; clean → none
- browser back while dirty → prompt; Stay → the editor stays and the URL bar shows the editor (R1)
- browser forward afterwards
- iPad: swipe-back blocked while dirty and the prompt shows; Save on flaky network → busy state, dialog locked

## 8. Risks
- R1: On web, Stay after browser back. go_router 18.0.1 just declines the configuration when onExit is false. The browser history has already moved, so the URL bar may show the previous URL while the editor stays. Candidate mitigation, to be verified manually: on Stay from a browser-originated exit, re-report the current location (`router.go(currentUri)`). This is a known go_router limitation; it does not change UX.
- R2: onExit runs on the root navigator context. The dialog is shown there, while page errors use the page's `ScaffoldMessenger`, which is still mounted. The pageKey registry has to unregister in `dispose` to avoid stale guards.
- R3: `_personIdsToWrite` is null while `_unloadedPersonIds` is non-empty (`new_story_page.dart:157-159`). A person removal then can't be persisted by either save path. This is pre-existing. The prompt still shows, but Save leaves story_people as it is.
- R4: A session that expires while the user is dirty is not prompted (signed-out redirect allowed); unsaved input is lost, as today.
- R5: Rename `_load()` overwrites an unsaved rename after other actions (`manage_family_page.dart:112, 157…316`). This is pre-existing and out of #82 scope.
- R6: `_onSaveDraft` and `_onSaveChanges` gate on a date (`:153-155`). See OPEN-1.

## 9. OPEN (for Bill / Mugatu)
- **OPEN-1. Save on a New story with no date.** The prompt shows for a place-only form, or for typing inside 2 s on an undated draft. But Save draft is disabled without a date (`:153, :699, :861-863`) and has no error copy.
  - (a) Save is blocked: the dialog closes and the user stays, with no message. This is the literal UX :58 reading.
  - (b) For this case only, Save runs the autosave flush (`allowUndated`, `:637-640`), which keeps an undated draft.
  - (c) Leave Save enabled but highlight the timeframe the way the photo cue does (`_highlightTimeframeForPhoto`). That is new UX.
  - **Recommend (a)**, the locked text. Choose (b) only if Bill wants "Save" to always keep typing.
- **OPEN-2. Start a family from New/Edit story with unsaved input: order.**
  - (a) Start-a-family dialog first, then the prompt. On Stay, the new family exists but isn't selected, and the user stays.
  - (b) Prompt first, then the dialog. If the dialog is cancelled after Save or Discard, the user stays with the input already saved or dropped.
  - **Recommend (a)**: the prompt sits at the real exit, and Stay never changes the session family.
- **OPEN-3. "Phone widths" for the stacked buttons.** UX :45 gives no number and the repo has no phone constant. Existing breakpoints are 640 (`story_reader_page.dart:1301`) and 720 (`manage_family_page.dart:733`).
  - (a) < 600 (Material compact)
  - (b) < 640, matching the reader
  - **Recommend (b)** (reuse an in-repo value). Mugatu to confirm.

## Resolutions (2026-10-22 6:31 AM CT)
- OPEN-2 resolved (Gilfoyle; Mugatu confirmed): leave prompt first, then Start-a-family dialog. Stay creates nothing; Save/Discard then opens Start-a-family.
- OPEN-3 resolved (Mugatu): buttons stack < 640 px (story_reader_page.dart:1301), Save on top.
- "Existing error" = that page's current save-path error; Edit story = Save changes date check, not the Publish banner (uxd-handoff :58 is Publish).
- OPEN-1 RESOLVED (Bill via Erlich, 2026-10-22 6:36 AM CT, verbatim: "#82 no-date Save: (a) blocked, dialog closes, stay on the story, nothing lost"). Prompt Save on an undated New story: no write, dialog closes, user stays on the page, unsaved input retained; no new copy.

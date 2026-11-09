# M9 Reader modal + Macro year tap

> Gate: plan only until approved. No application code before.
>
> On approval: copy file to `docs/superpowers/plans/2026-10-05-m9-reader-modal.md` in first commit. Worktree `.worktrees/feat-m9-reader-modal`, branch `feat/m9-reader-modal`, from **`origin/main` `e391f85`** (`feat: share the mid sub-header and slide the zoom pill (#21)`). Local `main` at `0d745b7` behind that commit. No branch from local checkout.

**Goal:** Tap story on timeline → published reader opens as parchment sheet over dimmed, blurred timeline. Sheet matches Stitch `221229a5b4844e7a9b3a2d1b3ef034e5` for existing fields. Close → same timeline position + zoom. Tap year on Macro → Mid centered on that year. Family co-members read each other's avatar file. Exit = Bill local smoke. Open one PR. No merge. No claim Bill smoke.

**Architecture:** One reader body, two shells. Timeline tap pushes existing `/stories/:storyId` route with `extra: ReaderPresentation.modal`, non-opaque page, so timeline route stays mounted under. Search + pasted `/stories/:id` link keep full-page shell + Timeline back control. Only migration drops `avatars_select_own`, adds `avatars_select_own_or_comember`. No new table, column, Edge function, package.

**Tech stack:** Flutter 3.x, `albumTheme()`, `go_router`, existing PostgREST reader query, private Storage buckets `avatars` + `story-photos`. No new package.

## Sources

- Impl Spec §15 M9, status READY, not CLOSED: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Impl Spec §10 Reader row + superseded-screen list. Null title on this reader paints blank.
- UXD M9 (Bill, 2026-10-05): https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- Design Doc “M9 avatar visibility” + “M9 reader data map” (Gilfoyle, 2026-10-05): https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- Screen: Stitch project `12192342757314667328`, screen `221229a5b4844e7a9b3a2d1b3ef034e5` (Story Reader Modal). HTML resource `projects/12192342757314667328/files/18089657997670507422`. Screenshot `…/files/3615877982651112793`. Desktop 2560×2048.
- Ignore for this look: `e3692b8710ea4fe395d9e03ebdf1a934` + full-page reader `3ca683beb0144a658fd5074b665fe6af`.
- Code base `origin/main` `e391f85`. Far, mid, full cards already share `_DialSubheader`. Macro chip already `dialFocusLabel` (`1980 · IN FOCUS`), not `1980s · IN FOCUS`. No rebuild of bar or sliding pill.

## Global constraints

- No reopen M6, M7, M8, R2, R3. No restyle R2 header. No change to zoom fade, newest-first order, dashed branch rail, 240ms zoom pill.
- No new table, column, Edge function, package. No edit `supabase/migrations/20261005000001_profile_avatar.sql`.
- No denormalize `display_name` or `avatar_path` onto `stories`.
- Bucket `avatars` stays private. No `getPublicUrl`. INSERT, UPDATE, DELETE stay own-object only.
- No Print or Share. No photo caption. `photos` has no caption column.
- No `stories.created_at`. Documented month/year = `published_at`.
- Stitch demo copy stays off: Jenkins, Sarah Jenkins, “Blackberry patch…”, “3 preserved items”, “1970s Decade”, “Alternate Family Perspectives”, “Family Notes & Memories”, “Add your version”.
- Comments + Perspectives stay separate, existing section titles + controls.
- Tokens stay parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`. Newsreader headlines, Literata body, Source Sans 3 labels.

## Modal

Story tap pushes `/stories/:id` with `extra: ReaderPresentation.modal`.

```dart
enum ReaderPresentation { page, modal }
```

Enum in `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart`. `StoryReaderPage` takes `this.presentation = ReaderPresentation.page`.

Story `GoRoute` uses `CustomTransitionPage` when `state.extra == ReaderPresentation.modal`:

- `opaque: false`
- `barrierDismissible: false`
- immediate transition (`duration: Duration.zero`)
- child = `Stack`, first layer `BackdropFilter` (`ImageFilter.blur(sigmaX: 8, sigmaY: 8)`) + dim `ColoredBox` at `Color(0x661C140C)`
- sheet centered on top

Search `Read Story →` keeps `context.push(AppRoutes.storyPath(id))`, no extra. Cold load of `/stories/:id` has no extra. Both use page shell.

Page shell stays current `Scaffold` + `AlbumTopBar` + Timeline back control (`context.go(AppRoutes.timeline)`). Modal shell: no back link, no second app bar.

### Sheet chrome

Key `story-reader-modal`. Fill `#FBF7F2`. Radius 16. 1px border `#E6DCD1`. Max width 1040. Margin 24 each side. Max height = viewport minus 48. Sheet scrolls inside (`SingleChildScrollView`). Timeline under it no scroll.

Top bar, one row:

| Side | Widget | Behavior |
| --- | --- | --- |
| Left | Text `Family Keepsake` | Static. Source Sans 3, ~12px, letter-spacing ~1.2, terracotta. Not link. |
| Right | `IconButton` `Icons.close`, key `story-reader-close` | `Navigator.pop`. No Print. No Share. |

Pop returns to `/timeline`. Timeline `State` never disposed, so zoom, focused story, scroll offset same as before push.

### Story taps

These three call `_openStory`, pushes modal extra. URL becomes `/stories/:id` while sheet up. Timeline page stays in stack.

| Control | Key | Today, on `e391f85` | After this plan |
| --- | --- | --- | --- |
| Far dot | `timeline-dot-<id>` | `_openMid` | modal |
| Mid stub | `timeline-stub-<id>` | `_openNear` | modal |
| Full card | `timeline-card-<id>` | `context.push` with no extra | modal extra |

Macro / Mid / Full Cards switch, pinch, `+`, `−`, Fit unchanged. Dot no longer way into Mid.

## Reader body

One body, both shells. Order under sheet bar (page shell: under existing Timeline bar):

1. Headline. `readerHeadline` returns trimmed `stories.title`. Null/blank title → `''`, headline widget omitted. No `Untitled`. Drafts + `storyTitle` on timeline unchanged.
2. Meta line. One line, wraps. No separate “Written by” line.
3. Chips: people, place, decade.
4. Wide hero. Photo with lowest `sort_order`. No photo → no image block.
5. Body, drop cap kept, full body incl. first line.
6. Existing Keepsake photos section, Perspectives, Comments, incl. `+ Add photos`, `+ Add your perspective`, `+ Add comment`, hidden composer, own-comment Delete.

Location card + Mapbox preview removed from this body. Place = chip. `PlaceMap` stays on place picker.

### Meta line

Visible pattern:

`Recorded event: {event date} · Documented {month year} by {author}` + avatar circle + `· {n} min read`

Avatar = widget, not characters. Use existing date helpers. No second formatter.

| Piece | Source | Format |
| --- | --- | --- |
| Recorded event | `timeframe_start`, plus `timeframe_end` when set + not same calendar day | `_albumDate` (`Jul 24, 1974`). Range = `{start} – {end}`. |
| Documented | `published_at` only | `_albumMonthYear` (`Oct 2023`). `published_at` null → omit `Documented …` segment. No read `created_at`. |
| Author | `profiles.display_name` via existing author embed | `displayNameOrMember`. Blank stored name paints `Member`. |
| Avatar | `profiles.avatar_path` for `stories.author_id` | M8 circle, 20×20. See below. |
| Min read | `stories.body`, client only | `minutesToRead`. Nothing stored. |

```dart
int minutesToRead(String? body) {
  final words = (body ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
  final minutes = (words / 200).ceil();
  return minutes < 1 ? 1 : minutes;
}
```

Label `{n} min read` for every n, incl. 1. Empty body = `1 min read`.

`minutesToRead`, `recordedEventLabel`, `decadeChipLabel` go in `apps/tell_me_a_story/lib/features/stories/reader_meta.dart` so arithmetic provable without widget tests.

```dart
String recordedEventLabel({
  required DateTime start,
  DateTime? end,
}) { /* _albumDate; en dash when end is a different day */ }

String decadeChipLabel(DateTime start) {
  final decade = (start.year ~/ 10) * 10;
  return '${decade}s';
}
```

1974-07-24 → `1970s`. Not `1970s Decade`. Not y-m-d string.

### Chips

People stay current chips: initials from person's name, `people.name`, `people.relationship`. From existing `listPeople` filter on `story.personIds`.

Place chip text = `place.label` when trim non-empty, else `place.address`. No place → no place chip. No map, no “Story Location” card.

Decade chip = `decadeChipLabel(story.timeframeStart)`. Independent of `timeframe_end`.

### Hero and the rest of the photos

Sort loaded photos by `sort_order`, then id. First = hero: sheet content width, aspect 16:9, `BoxFit.cover`, parchment behind missing decode. No caption, no date under.

Keepsake section below body lists every photo incl. hero, existing add/remove controls, cap 20. No captions. `Add photos` stays.

### Avatar circle

Reuse `ProfileAvatar` (`lib/core/theme/profile_avatar.dart`).

- `avatar_path` set + download succeeds: JPEG fills circle. No initials on top.
- `avatar_path` null or download throws: initials from author's saved `display_name` via `profileInitials`. No pass `Member` fallback into `profileInitials`. Blank stored name → empty circle.

Load via signed URL from private `avatars` bucket. Add `ProfileGateway.downloadAvatar` use, or package-visible helper on `ProfileApi`, calling `storage.from('avatars').createSignedUrl(path, 3600)` then reading bytes. No `getPublicUrl`. Test stub returns bytes or throws. Failed URL → initials.

Extend author embed. In `StoriesApi`, `profiles!author_id(...)` select gains `avatar_path`. `Story` gains `authorAvatarPath`. `Story.fromJson` reads it same as `display_name`. No column added.

`getPublished` stays reader query. Draft ids still return null, page still paints `Not found`.

## Macro year tap

Macro only, two controls call `_openMidOnYear(int year)`:

| Control | Key | Year |
| --- | --- | --- |
| Year chip in `_DialSubheader` | `timeline-year-chip` | `year` already passed into that bar (`_centerYear`, focused decade's start year) |
| Decade label on rail (`1980s`) | `timeline-decade-<startYear>` | That band's `startYear` |

On Mid + Full Cards year chip not a button. Chip string stays `dialFocusLabel` (`1980 · IN FOCUS`).

`_openMidOnYear`:

- Take `dialStories` (published, newest `timeframe_start` first).
- Pick story whose `timeframeStart.year` closest to `year`. First closest in newest-first list wins → tie keeps newer story.
- Set zoom `TimelineZoom.mid`, set `_focusedStoryId` to that story, `_reveal` it so `Scrollable.ensureVisible(..., alignment: 0.5)` centers it.
- Mid chip = `dialFocusLabel` of that story's year. Story in tapped year → chip matches tapped year.

No new screen. No new route. Mid button on switch still uses existing focus story, no call to `_openMidOnYear`.

## Avatar visibility

New file `supabase/migrations/20261005000002_avatars_select_comember.sql`. No edit `20261005000001_profile_avatar.sql`.

```sql
drop policy if exists avatars_select_own on storage.objects;

create policy avatars_select_own_or_comember
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (
      name = (auth.uid()::text || '/avatar.jpg')
      or exists (
        select 1
        from public.memberships mine
        join public.memberships theirs
          on theirs.family_id = mine.family_id
        where mine.user_id = auth.uid()
          and name = (theirs.user_id::text || '/avatar.jpg')
      )
    )
  );
```

`avatars_insert_own`, `avatars_update_own`, `avatars_delete_own` stay. Bucket stays `public = false`.

## Files

### Create

| Path | Responsibility |
| --- | --- |
| `supabase/migrations/20261005000002_avatars_select_comember.sql` | Replace own-only avatar SELECT with co-member policy above |
| `supabase/tests/avatars_select_comember.sql` | Co-member can select. Stranger cannot. After B's write attempts, A's object still there, unchanged |
| `lib/features/stories/reader_meta.dart` | `minutesToRead`, `recordedEventLabel`, `decadeChipLabel` |

### Edit

| Path | Change |
| --- | --- |
| `lib/features/stories/story_reader_page.dart` | `ReaderPresentation`. Modal shell vs page shell. Meta line, chips, hero. Blank headline. Drop location map from body. |
| `lib/core/router/app_router.dart` | Modal extra → non-opaque page. Page shell when extra absent. Pass `presentation` through. |
| `lib/features/timeline/timeline_page.dart` | `_openStory` for dot, stub, card. `_openMidOnYear` for Macro year chip + decade label. |
| `lib/data/stories_api.dart` | `authorAvatarPath` on author embed + `Story`. |
| `lib/data/profile_api.dart` | Signed-URL download of avatar object. Stubbable. No public URL. |
| `test/story_reader_page_test.dart` | Meta line, blank title, hero, no Print/Share, modal close. |
| `test/timeline_page_test.dart` | Story taps open modal, timeline stays mounted. Year tap opens Mid. Dot tap no longer opens Mid. |
| `test/reader_meta_test.dart` | Word count, date range, decade chip. |

### Leave alone

- `20261005000001_profile_avatar.sql` + email trigger.
- Zoom pill, far fade, branch dashes, Realtime publication, search indexes.
- Album header, Settings, invite modal, New Story, Drafts.
- Add Perspective form. Comment composer open/close rules.
- `storyTitle` / `Untitled` on drafts + timeline. Search cards still print blank title as nothing.

## Tests

From `apps/tell_me_a_story`, `flutter test`.

`reader_meta_test.dart`:

- 0 words + blank body = `1`. 200 words = `1`. 201 words = `2`.
- Single day = `_albumDate` of start. Different end date joins with ` – `.
- `decadeChipLabel` of 1974-07-24 = `1970s`.

`story_reader_page_test.dart`:

- `readerHeadline(title: null)` + whitespace title = `''`. Saved title = that title. Article still includes first body line.
- Meta line contains `Recorded event:`, `Documented`, author name, `1 min read` for short body. No `Written by`.
- Story with no `published_at` has no `Documented`.
- People chip, place chip (label; address when label blank), `1970s` present. Location-card map absent.
- First photo by `sort_order` = hero. No Stitch caption string present.
- `find.text('Print')` + `find.text('Share')` find nothing.
- Page shell still finds Timeline back control + `story-reader`.
- Modal shell finds `Family Keepsake` + `story-reader-close`, no Timeline back control. Close button pops.

`timeline_page_test.dart`:

- Tap `timeline-year-chip` on Macro, or `timeline-decade-1980` → Mid with centered story's `{year} · IN FOCUS` + `Zoom Level: 45% (Stubs & Eras)`. Path stays `/timeline`.
- Tap `timeline-dot-<id>`, `timeline-stub-<id>`, or `timeline-card-<id>` → finds `story-reader-modal`. Matched location contains `/stories/<id>`. `Invite` still in tree. After `story-reader-close`, path `/timeline`, zoom label same as before tap.
- Tests that today tap dot to reach Mid → tap `timeline-year-chip` or decade key instead.
- Mid + Full Cards year chips push no route.

`supabase/tests/avatars_select_comember.sql`, same harness shape as `profiles_comember_select.sql` (`begin` / `plan` / `rollback`, `create_family`, postgres membership insert):

- Insert `storage.objects` as postgres for user A's `{id}/avatar.jpg` in bucket `avatars`. Set `owner_id` only if table requires.
- As co-member B, `select` of that name returns 1 row.
- As user C in other family, `select` returns 0 rows.
- As B, update A's object + delete A's object. No `throws_ok`. `INSERT` of A's path raises under RLS, would abort script, so that one statement sits in `begin … exception when others then null; end` block. Block only lets script reach check. Not the assertion.
- `reset role`. As table owner, exactly one `storage.objects` row with bucket `avatars` + name `{A}/avatar.jpg`. Name unchanged. No second row uses A's path.

`flutter test` output goes in PR. `supabase test db` for `avatars_select_comember.sql` only if local Supabase already running. No DB reset. Not running → say so.

## Git and PR

- `git fetch origin`, then from repo root: `git worktree add .worktrees/feat-m9-reader-modal -b feat/m9-reader-modal origin/main`
- Confirm `HEAD` is `e391f85` before editing.
- One PR, `feat(m9): reader modal`. No merge. No force-push.
- PR body: timeline opens Stitch `221229a5b4844e7a9b3a2d1b3ef034e5` as modal over blurred timeline; X returns to same zoom; `/stories/:id` stays deep link + search target; Macro year tap opens Mid; co-members can read avatar objects; Print, Share, photo captions not built; Bill smoke not claimed.

## Out

Print. Share. Photo captions. Public `avatars` bucket or `getPublicUrl`. Editing M8 migration. New column or `stories.created_at`. Denormalizing author onto `stories`. Matching `e3692b87` or `3ca683be`. Rebuilding zoom pill or far fade. Changing search cards, drafts, R2 header. Edit story. Voice memo. “1970s Decade”. Stitch demo names.

## Conflict check

- R1 painted `Untitled` for blank reader title. Impl Spec §10, M9 row, now says null title paints blank. Plan follows §10. `storyTitle` on timeline + drafts still returns `Untitled`.
- R2 says reader keeps back control. Stays on page shell. Modal has X, no back link = M9 lock.
- M6 taught “tap a dot, then a stub, then a card” as zoom ladder. M9: story tap opens reader, year tap opens Mid. Switch, pinch, Fit still change zoom. Dot, stub, card open modal.
- Design Doc M8 said co-member no avatar file. Same doc's M9 section supersedes SELECT only. Writes stay own-only.
- FA far-zoom chrome already `e391f85`. Plan no restyle. Adds tap on year chip bar already paints.
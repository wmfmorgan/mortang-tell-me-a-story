# M9 Reader modal + Macro year tap

> Gate: plan only until this plan is approved. Do not write application code before that.
>
> On approval: copy this file to `docs/superpowers/plans/2026-10-05-m9-reader-modal.md` in the first commit. Worktree `.worktrees/feat-m9-reader-modal`, branch `feat/m9-reader-modal`, from **`origin/main` `e391f85`** (`feat: share the mid sub-header and slide the zoom pill (#21)`). Local `main` at `0d745b7` is behind that commit. Do not branch from the local checkout.

**Goal:** Tapping a story on the timeline opens the published reader as a parchment sheet over the dimmed, blurred timeline. The sheet matches Stitch `221229a5b4844e7a9b3a2d1b3ef034e5` for fields that exist. Closing returns to the same timeline position and zoom. Tapping a year on Macro opens Mid centered on that year. Family co-members can read each other's avatar file. Exit is Bill local smoke. Open one PR. Do not merge. Do not claim Bill smoke.

**Architecture:** One reader body, two shells. A timeline tap pushes the existing `/stories/:storyId` route with `extra: ReaderPresentation.modal`, on a non-opaque page, so the timeline route stays mounted underneath. Search and a pasted `/stories/:id` link keep the full-page shell and its Timeline back control. The only migration drops `avatars_select_own` and adds `avatars_select_own_or_comember`. No new table, column, Edge function, or package.

**Tech stack:** Flutter 3.x, `albumTheme()`, `go_router`, existing PostgREST reader query, private Storage buckets `avatars` and `story-photos`. No new package.

## Sources

- Impl Spec §15 M9, status READY, not CLOSED: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Impl Spec §10 Reader row and the superseded-screen list. Null title on this reader paints blank.
- UXD M9 (Bill, 2026-10-05): https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- Design Doc “M9 avatar visibility” and “M9 reader data map” (Gilfoyle, 2026-10-05): https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- Screen: Stitch project `12192342757314667328`, screen `221229a5b4844e7a9b3a2d1b3ef034e5` (Story Reader Modal). HTML resource `projects/12192342757314667328/files/18089657997670507422`. Screenshot `…/files/3615877982651112793`. Desktop 2560×2048.
- Ignore for this look: `e3692b8710ea4fe395d9e03ebdf1a934` and full-page reader `3ca683beb0144a658fd5074b665fe6af`.
- Code base is `origin/main` `e391f85`. Far, mid, and full cards already share `_DialSubheader`. The Macro chip is already `dialFocusLabel` (`1980 · IN FOCUS`), not `1980s · IN FOCUS`. Do not rebuild that bar or the sliding pill.

## Global constraints

- Do not reopen M6, M7, M8, R2, or R3. Do not restyle the R2 header. Do not change zoom fade, newest-first order, the dashed branch rail, or the 240ms zoom pill.
- No new table, column, Edge function, or package. Do not edit `supabase/migrations/20261005000001_profile_avatar.sql`.
- Do not denormalize `display_name` or `avatar_path` onto `stories`.
- Bucket `avatars` stays private. No `getPublicUrl`. INSERT, UPDATE, and DELETE stay own-object only.
- Do not build Print or Share. Do not build a photo caption. `photos` has no caption column.
- Do not add `stories.created_at`. Documented month/year is `published_at`.
- Stitch demo copy stays off: Jenkins, Sarah Jenkins, “Blackberry patch…”, “3 preserved items”, “1970s Decade”, “Alternate Family Perspectives”, “Family Notes & Memories”, “Add your version”.
- Comments and Perspectives stay separate, with the section titles and controls they already have.
- Tokens stay parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`. Newsreader headlines, Literata body, Source Sans 3 labels.

## Modal

A story tap pushes `/stories/:id` with `extra: ReaderPresentation.modal`.

```dart
enum ReaderPresentation { page, modal }
```

Put the enum in `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart`. `StoryReaderPage` takes `this.presentation = ReaderPresentation.page`.

The story `GoRoute` uses a `CustomTransitionPage` when `state.extra == ReaderPresentation.modal`:

- `opaque: false`
- `barrierDismissible: false`
- transition is immediate (`duration: Duration.zero`)
- the child is a `Stack` whose first layer is `BackdropFilter` (`ImageFilter.blur(sigmaX: 8, sigmaY: 8)`) plus a dim `ColoredBox` at `Color(0x661C140C)`
- the sheet sits centered on top

Search `Read Story →` keeps `context.push(AppRoutes.storyPath(id))` with no extra. A cold load of `/stories/:id` has no extra. Both use the page shell.

The page shell stays the current `Scaffold` plus `AlbumTopBar` and the Timeline back control (`context.go(AppRoutes.timeline)`). The modal shell has no back link and no second app bar.

### Sheet chrome

Key `story-reader-modal`. Fill `#FBF7F2`. Radius 16. 1px border `#E6DCD1`. Max width 1040. Margin 24 on each side. Max height is the viewport minus 48. The sheet scrolls inside itself (`SingleChildScrollView`). The timeline under it does not scroll.

Top bar, one row:

| Side | Widget | Behavior |
| --- | --- | --- |
| Left | Text `Family Keepsake` | Static. Source Sans 3, about 12px, letter-spacing about 1.2, terracotta. Not a link. |
| Right | `IconButton` `Icons.close`, key `story-reader-close` | `Navigator.pop`. No Print. No Share. |

Pop returns to `/timeline`. The timeline `State` was never disposed, so zoom, focused story, and scroll offset are the ones from before the push.

### Story taps

These three call `_openStory`, which pushes the modal extra. The URL becomes `/stories/:id` while the sheet is up. The timeline page stays in the stack.

| Control | Key | Today, on `e391f85` | After this plan |
| --- | --- | --- | --- |
| Far dot | `timeline-dot-<id>` | `_openMid` | modal |
| Mid stub | `timeline-stub-<id>` | `_openNear` | modal |
| Full card | `timeline-card-<id>` | `context.push` with no extra | modal extra |

The Macro / Mid / Full Cards switch, pinch, `+`, `−`, and Fit stay as they are. A dot is no longer the way into Mid.

## Reader body

One body for both shells. Order under the sheet bar (page shell: under the existing Timeline bar):

1. Headline. `readerHeadline` returns the trimmed `stories.title`. A null or blank title returns `''`, and the headline widget is omitted. Do not paint `Untitled`. Drafts and `storyTitle` on the timeline stay as they are.
2. Meta line. One line, wraps. No separate “Written by” line.
3. Chips: people, then place, then decade.
4. Wide hero. The photo with the lowest `sort_order`. No photo means no image block.
5. Body, drop cap kept, full body including the first line.
6. The existing Keepsake photos section, Perspectives, and Comments, including `+ Add photos`, `+ Add your perspective`, `+ Add comment`, the hidden composer, and own-comment Delete.

The location card and its Mapbox preview come off this body. Place is a chip. `PlaceMap` stays on the place picker.

### Meta line

Visible pattern:

`Recorded event: {event date} · Documented {month year} by {author}` + avatar circle + `· {n} min read`

The avatar is a widget, not characters. Use the existing date helpers. Do not add a second formatter.

| Piece | Source | Format |
| --- | --- | --- |
| Recorded event | `timeframe_start`, plus `timeframe_end` when set and not the same calendar day | `_albumDate` (`Jul 24, 1974`). A range is `{start} – {end}`. |
| Documented | `published_at` only | `_albumMonthYear` (`Oct 2023`). If `published_at` is null, omit the `Documented …` segment. Do not read `created_at`. |
| Author | `profiles.display_name` via the existing author embed | `displayNameOrMember`. Blank stored name paints `Member`. |
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

The label is `{n} min read` for every n, including 1. An empty body is `1 min read`.

Put `minutesToRead`, `recordedEventLabel`, and `decadeChipLabel` in `apps/tell_me_a_story/lib/features/stories/reader_meta.dart` so widget tests are not required to prove the arithmetic.

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

1974-07-24 is `1970s`. Not `1970s Decade`. Not the y-m-d string.

### Chips

People stay the current chips: initials from the person's name, `people.name`, `people.relationship`. They come from the existing `listPeople` filter on `story.personIds`.

Place chip text is `place.label` when that trim is non-empty, otherwise `place.address`. No place means no place chip. No map, no “Story Location” card.

Decade chip is `decadeChipLabel(story.timeframeStart)`. It does not depend on `timeframe_end`.

### Hero and the rest of the photos

Sort the loaded photos by `sort_order`, then id. The first is the hero: width of the sheet content, aspect ratio 16:9, `BoxFit.cover`, parchment behind a missing decode. No caption and no date under it.

The Keepsake section below the body lists every photo, including the hero, with the existing add and remove controls and the cap of 20. No captions. `Add photos` stays.

### Avatar circle

Reuse `ProfileAvatar` (`lib/core/theme/profile_avatar.dart`).

- `avatar_path` set and the download succeeds: the JPEG fills the circle. No initials on top.
- `avatar_path` null, or the download throws: initials from the author's saved `display_name` via `profileInitials`. Do not pass the `Member` fallback into `profileInitials`. A blank stored name paints an empty circle.

Load with a signed URL from the private `avatars` bucket. Add `ProfileGateway.downloadAvatar` use, or a package-visible helper on `ProfileApi`, that calls `storage.from('avatars').createSignedUrl(path, 3600)` and then reads those bytes. Do not call `getPublicUrl`. A test stub returns bytes or throws. A failed URL paints initials.

Extend the author embed. In `StoriesApi`, the `profiles!author_id(...)` select gains `avatar_path`. `Story` gains `authorAvatarPath`. `Story.fromJson` reads it the same way it reads `display_name`. Do not add a column.

`getPublished` stays the reader query. Draft ids still come back null and the page still paints `Not found`.

## Macro year tap

On Macro only, two controls call `_openMidOnYear(int year)`:

| Control | Key | Year |
| --- | --- | --- |
| The year chip in `_DialSubheader` | `timeline-year-chip` | The `year` already passed into that bar (`_centerYear`, which is the focused decade's start year) |
| The decade label on the rail (`1980s`) | `timeline-decade-<startYear>` | That band's `startYear` |

On Mid and Full Cards the year chip is not a button. The chip string stays `dialFocusLabel` (`1980 · IN FOCUS`).

`_openMidOnYear`:

- Take `dialStories` (published, newest `timeframe_start` first).
- Choose the story whose `timeframeStart.year` is closest to `year`. The first closest in that newest-first list wins, so a tie keeps the newer story.
- Set zoom to `TimelineZoom.mid`, set `_focusedStoryId` to that story, and `_reveal` it so `Scrollable.ensureVisible(..., alignment: 0.5)` centers it.
- The Mid chip is `dialFocusLabel` of that story's year. A story in the tapped year makes the chip match the tapped year.

No new screen. No new route. The Mid button on the switch still uses the existing focus story. It does not call `_openMidOnYear`.

## Avatar visibility

New file `supabase/migrations/20261005000002_avatars_select_comember.sql`. Do not edit `20261005000001_profile_avatar.sql`.

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

`avatars_insert_own`, `avatars_update_own`, and `avatars_delete_own` stay. The bucket stays `public = false`.

## Files

### Create

| Path | Responsibility |
| --- | --- |
| `supabase/migrations/20261005000002_avatars_select_comember.sql` | Replace own-only avatar SELECT with the co-member policy above |
| `supabase/tests/avatars_select_comember.sql` | Co-member can select. Stranger cannot. After B's write attempts, A's object is still there and unchanged |
| `lib/features/stories/reader_meta.dart` | `minutesToRead`, `recordedEventLabel`, `decadeChipLabel` |

### Edit

| Path | Change |
| --- | --- |
| `lib/features/stories/story_reader_page.dart` | `ReaderPresentation`. Modal shell vs page shell. Meta line, chips, hero. Blank headline. Drop the location map from this body. |
| `lib/core/router/app_router.dart` | Modal extra → non-opaque page. Page shell when extra is absent. Pass `presentation` through. |
| `lib/features/timeline/timeline_page.dart` | `_openStory` for dot, stub, and card. `_openMidOnYear` for the Macro year chip and the decade label. |
| `lib/data/stories_api.dart` | `authorAvatarPath` on the author embed and `Story`. |
| `lib/data/profile_api.dart` | Signed-URL download of an avatar object. Stubbable. No public URL. |
| `test/story_reader_page_test.dart` | Meta line, blank title, hero, no Print/Share, modal close. |
| `test/timeline_page_test.dart` | Story taps open the modal and leave the timeline mounted. Year tap opens Mid. Dot tap no longer opens Mid. |
| `test/reader_meta_test.dart` | Word count, date range, decade chip. |

### Leave alone

- `20261005000001_profile_avatar.sql` and the email trigger.
- Zoom pill, far fade, branch dashes, Realtime publication, search indexes.
- Album header, Settings, invite modal, New Story, Drafts.
- Add Perspective form. Comment composer open/close rules.
- `storyTitle` / `Untitled` on drafts and the timeline. Search cards still print a blank title as nothing.

## Tests

From `apps/tell_me_a_story`, `flutter test`.

`reader_meta_test.dart`:

- 0 words and a blank body are `1`. 200 words are `1`. 201 words are `2`.
- A single day is `_albumDate` of the start. A different end date joins with ` – `.
- `decadeChipLabel` of 1974-07-24 is `1970s`.

`story_reader_page_test.dart`:

- `readerHeadline(title: null)` and a whitespace title are `''`. A saved title is that title. The article still includes the first body line.
- The meta line contains `Recorded event:`, `Documented`, the author name, and `1 min read` for a short body. It does not contain `Written by`.
- A story with no `published_at` does not contain `Documented`.
- People chip, place chip (label; address when the label is blank), and `1970s` are present. The location-card map is absent.
- The first photo by `sort_order` is the hero. No caption string from the Stitch screen is present.
- `find.text('Print')` and `find.text('Share')` find nothing.
- Page shell still finds the Timeline back control and `story-reader`.
- Modal shell finds `Family Keepsake` and `story-reader-close`, and does not find the Timeline back control. The close button pops.

`timeline_page_test.dart`:

- Tapping `timeline-year-chip` on Macro, or `timeline-decade-1980`, lands on Mid with the centered story's `{year} · IN FOCUS` and `Zoom Level: 45% (Stubs & Eras)`. The path stays `/timeline`.
- Tapping `timeline-dot-<id>`, `timeline-stub-<id>`, or `timeline-card-<id>` finds `story-reader-modal`. The matched location contains `/stories/<id>`. `Invite` is still in the tree. After `story-reader-close`, the path is `/timeline` and the zoom label is the one from before the tap.
- Tests that today tap a dot to reach Mid tap `timeline-year-chip` or the decade key instead.
- The Mid and Full Cards year chips do not push a route.

`supabase/tests/avatars_select_comember.sql`, same harness shape as `profiles_comember_select.sql` (`begin` / `plan` / `rollback`, `create_family`, postgres membership insert):

- Insert `storage.objects` as postgres for user A's `{id}/avatar.jpg` in bucket `avatars`. Set `owner_id` only if the table requires it.
- As co-member B, `select` of that name returns 1 row.
- As user C in another family, `select` returns 0 rows.
- As B, update A's object and delete A's object. Do not use `throws_ok`. An `INSERT` of A's path raises under RLS and would abort the script, so that one statement sits in a `begin … exception when others then null; end` block. That block is only there so the script reaches the check. It is not the assertion.
- `reset role`. As the table owner, exactly one `storage.objects` row has bucket `avatars` and name `{A}/avatar.jpg`. Its name is unchanged. No second row uses A's path.

`flutter test` output goes in the PR. `supabase test db` for `avatars_select_comember.sql` only if local Supabase is already running. Do not reset the database. If it is not running, say so.

## Git and PR

- `git fetch origin`, then from the repo root: `git worktree add .worktrees/feat-m9-reader-modal -b feat/m9-reader-modal origin/main`
- Confirm `HEAD` is `e391f85` before editing.
- One PR, `feat(m9): reader modal`. Do not merge. Do not force-push.
- PR body: the timeline opens Stitch `221229a5b4844e7a9b3a2d1b3ef034e5` as a modal over the blurred timeline; X returns to the same zoom; `/stories/:id` stays the deep link and the search target; Macro year tap opens Mid; co-members can read avatar objects; Print, Share, and photo captions are not built; Bill smoke is not claimed.

## Out

Print. Share. Photo captions. A public `avatars` bucket or `getPublicUrl`. Editing the M8 migration. A new column or `stories.created_at`. Denormalizing the author onto `stories`. Matching `e3692b87` or `3ca683be`. Rebuilding the zoom pill or the far fade. Changing search cards, drafts, or the R2 header. Edit story. Voice memo. “1970s Decade”. Stitch demo names.

## Conflict check

- R1 painted `Untitled` for a blank reader title. Impl Spec §10, M9 row, now says a null title paints blank. This plan follows §10. `storyTitle` on the timeline and drafts still returns `Untitled`.
- R2 says the reader keeps its back control. That stays on the page shell. The modal has X and no back link, which is the M9 lock.
- M6 taught “tap a dot, then a stub, then a card” as the zoom ladder. M9 says a story tap opens the reader, and a year tap opens Mid. The switch, pinch, and Fit still change zoom. Dot, stub, and card open the modal.
- Design Doc M8 said a co-member does not get the avatar file. The same doc's M9 section supersedes SELECT only. Writes stay own-only.
- FA far-zoom chrome is already `e391f85`. This plan does not restyle it. It adds a tap on the year chip that bar already paints.

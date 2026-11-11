# Phase 4c: Stories, Search, Timeline Live — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `StoriesApi`, `SearchApi`, timeline live feed talk to Serverpod server, not Supabase. Dropped `decade` precision (D9) leaves app.

**Architecture:** Each gateway keeps class name + interface (`SearchGateway` gains `facets`; 4c's only interface change). Gateways read generated client lazily (`_injected ?? serverClient`), wrap every `Future` call in `withServerErrors`. DTO → domain mapping = `fromDto` factory beside domain class. `ServerTimelineLive` replaces `SupabaseTimelineLive` on timeline; reader (`story_reader_page.dart`, slice 4e) swaps with one line since `TimelineLive` unchanged.

**Tech Stack:** Flutter 3.47.7, generated `tell_me_a_story_client` (Serverpod 4.1.1), `flutter_test`, just.

**Scope contract:** Phase 4 index, row "4c Stories, search, timeline live". Server behaviour: `apps/server/lib/src/endpoints/story_endpoint.dart`, `stories/story_search.dart`, `endpoints/live_endpoint.dart`.

**Landed** on `feat/p4c-stories-search`, one commit per task:
- `c314b44` Task 1, `213c316` Task 2, `0dba6a0` Task 3, `3a82bba` Task 4, `b55c31a` Task 5.
- Gate: format 0 changed; `flutter analyze` 23 issues (baseline); `flutter test` 727/727 (723 before); `just test-live` 6/6 (2 before) vs shared `just server`.
- Unit tests per file, before → after: `stories_api_test` 16 → 18, `search_api_test` 7 → 6, `search_page_test` 10 → 11, `gateway_errors_test` 13 → 8, `new_story_capture_test` 46 → 43, `timeline_page_test` 68 → 67, `timeline_live_test` new, 11. `story_date_test`, `all_stories_logic_test`, `drafts_page_test` same counts, cases rewritten.
- Diffs from steps below:
  - `story_date_test` also loses `decadeStartYear` case; that function left `stories_api.dart` in Task 3.
  - "published decade edit can save without replacing the date" became "a whole-year story opens with its year in the box", so edit load path keeps test.
  - Task 5 test + impl landed in one step. Tests written first, pass.

All commands run from `apps/tell_me_a_story` unless step says otherwise. `flutter`/`dart`/`just` run via `mise exec --`.

---

## File map

| Path | Responsibility |
|---|---|
| `lib/data/stories_api.dart` | `Story.fromDto`, `storyWriteDto`, `StoriesApi` on `story.*`, `downloadFirstThumbs` on `media.getMany`; `StoryDatePrecision` sans `decade` |
| `lib/data/search_api.dart` | `searchDto`, `SearchFacets.fromDto`, `SearchGateway.facets`, `SearchApi` on `story.search` / `story.facets`; `search` returns `List<Story>` |
| `lib/data/timeline_live.dart` | `timelineEventMatters(LiveEventDto)`, `ServerTimelineLive` (debounce, backoff resubscribe); `SupabaseTimelineLive` kept for reader until 4e swaps |
| `lib/features/search/search_page.dart` | person, place, decade chips from facets; no `placesApi` |
| `lib/features/stories/timeframe_chips.dart` | deleted (fixed 1900–2020 decades; `TimeframeChips` no caller since M13) |
| `lib/features/stories/story_date.dart` | no `legacyDecade` |
| `lib/features/timeline/timeline_page.dart` | `ServerTimelineLive()` default |
| `lib/features/stories/new_story_page.dart` | legacy decade load/save paths removed (D9 switch fallout) |
| `lib/features/settings/settings_page.dart` | `_storedBirth` drops `legacyDecade` check (one line, D9 fallout; 4d owns file) |
| `lib/core/router/app_router.dart` | `SearchPage` no longer takes `placesApi` (one line) |
| `test/stories_api_test.dart`, `all_stories_logic_test.dart`, `drafts_page_test.dart` | `fromDto` tests replace `fromJson` fixtures; duplicate-key + select-scan tests deleted |
| `test/search_api_test.dart`, `search_page_test.dart` | `searchDto` / `SearchFacets.fromDto` tests; page fake serves facets |
| `test/timeline_live_test.dart` | `timelineEventMatters` + `ServerTimelineLive` (fake `EndpointLive`) |
| `test/timeline_page_test.dart` | its `timelineEventMatters` case moves to `timeline_live_test.dart` |
| `test/story_date_test.dart`, `new_story_capture_test.dart` | decade cases deleted or moved to `year` |
| `test/gateway_errors_test.dart` | `StoriesApi` groups deleted with Supabase paths they covered |
| `test/live/support/story_fixtures.dart` | `seedFamily` (family + person + place via raw client) |
| `test/live/stories_live_test.dart`, `search_live_test.dart`, `server_timeline_live_test.dart` | live round trips |

Fakes of interfaces this slice changes: `SearchGateway` has one fake, `_Search` in `test/search_page_test.dart`. `StoriesGateway`, `TimelineLive` unchanged, fakes stay.

---

### Task 1: `Story.fromDto`

**Files:** Modify `lib/data/stories_api.dart` (class `Story`), Test `test/stories_api_test.dart`, `test/all_stories_logic_test.dart`, `test/drafts_page_test.dart`.

- [ ] **Step 1: Failing tests.** In `stories_api_test.dart` replace `Story.fromJson` cases with `fromDto` cases building DTOs directly:

```dart
server.StoryDto _dto({
  String? dateStart = '1987-03-04',
  server.DatePrecision? precision = server.DatePrecision.day,
  server.StoryStatus status = server.StoryStatus.published,
  List<server.StoryPersonDto> people = const [],
  List<server.PhotoRefDto> photos = const [],
  String? placeLabel,
  String? placeAddress,
  String? authorName,
}) => server.StoryDto(
  id: _storyId,
  familyId: _familyId,
  authorId: _authorId,
  title: 'Harbor',
  body: 'A day on the water',
  dateStart: dateStart == null ? null : DateTime.parse('${dateStart}T00:00:00Z'),
  dateEnd: dateStart == null ? null : DateTime.parse('${dateStart}T00:00:00Z'),
  datePrecision: precision,
  createdAt: DateTime.utc(2026, 1, 2, 3),
  placeId: _placeId,
  placeLabel: placeLabel,
  placeAddress: placeAddress,
  status: status,
  publishedAt: DateTime.utc(2026, 2, 3),
  people: people,
  photos: photos,
  authorName: authorName,
  authorAvatarKey: 'avatars/u.jpg',
  commentCount: 2,
  perspectiveCount: 1,
);

test('Story.fromDto maps ids, wire dates, precision and counts', () {
  final story = Story.fromDto(_dto());
  expect(story.id, _storyId.toString());
  expect(story.familyId, _familyId.toString());
  expect(story.authorId, _authorId.toString());
  expect(story.timeframeStart, DateTime(1987, 3, 4));
  expect(story.timeframeEnd, DateTime(1987, 3, 4));
  expect(story.datePrecision, StoryDatePrecision.day);
  expect(story.status, StoryStatus.published);
  expect(story.publishedAt, DateTime.utc(2026, 2, 3));
  expect(story.createdAt, DateTime.utc(2026, 1, 2, 3));
  expect(story.placeId, _placeId.toString());
  expect(story.authorAvatarPath, 'avatars/u.jpg');
  expect((story.commentCount, story.perspectiveCount), (2, 1));
});
```

plus: undated draft (`dateStart: null, precision: null` → null dates, `StoryStatus.draft`, default `day`); people (`personIds`, `people`, `personNames`, `personUserIds` only for linked person; blank names dropped from `people`/`personNames`, kept in `personIds`); trimmed `placeLabel`/`placeAddress`/`authorName`, blank → null; `photoPaths` = photo keys in server order, plus `photoCount`. `all_stories_logic_test` U-01 becomes `fromDto` test of address + person user ids; `drafts_page_test` and `compareStories` fixtures use `Story(...)` constructor.

- [ ] **Step 2:** `flutter test test/stories_api_test.dart` → FAIL (`fromDto` undefined).
- [ ] **Step 3: Implement** in `stories_api.dart`:

```dart
factory Story.fromDto(server.StoryDto dto) => Story(
  id: dto.id.toString(),
  familyId: dto.familyId.toString(),
  authorId: dto.authorId?.toString() ?? '',
  title: dto.title,
  body: dto.body,
  timeframeStart: fromWireDate(dto.dateStart),
  timeframeEnd: fromWireDate(dto.dateEnd),
  datePrecision: switch (dto.datePrecision) {
    server.DatePrecision.year => StoryDatePrecision.year,
    server.DatePrecision.month => StoryDatePrecision.month,
    server.DatePrecision.day || null => StoryDatePrecision.day,
  },
  createdAt: dto.createdAt,
  placeId: dto.placeId?.toString(),
  status: switch (dto.status) {
    server.StoryStatus.draft => StoryStatus.draft,
    server.StoryStatus.published => StoryStatus.published,
  },
  publishedAt: dto.publishedAt,
  personIds: [for (final person in dto.people) person.personId.toString()],
  photoCount: dto.photos.length,
  placeLabel: _trimmed(dto.placeLabel),
  people: [
    for (final person in dto.people)
      if (_trimmed(person.name) case final name?)
        (id: person.personId.toString(), name: name),
  ],
  personNames: [for (final person in dto.people) ?_trimmed(person.name)],
  authorDisplayName: _trimmed(dto.authorName),
  authorAvatarPath: _trimmed(dto.authorAvatarKey),
  commentCount: dto.commentCount,
  perspectiveCount: dto.perspectiveCount,
  photoPaths: [for (final photo in dto.photos) photo.key],
  placeAddress: _trimmed(dto.placeAddress),
  personUserIds: {
    for (final person in dto.people)
      if (person.userId case final userId?)
        person.personId.toString(): userId.toString(),
  },
);
```

`_trimmed(String?)` returns trimmed value, or null when blank. Server already orders `photos` (sortOrder, createdAt, id) and resolves each to edited key, so client doesn't re-sort.

- [ ] **Step 4:** three test files pass.
- [ ] **Step 5:** commit `feat(client): Story.fromDto`.

### Task 2: `StoriesApi` on the server

**Files:** Modify `lib/data/stories_api.dart`; Test `test/stories_api_test.dart`, `test/gateway_errors_test.dart`, `test/live/support/story_fixtures.dart`, `test/live/stories_live_test.dart`.

- [ ] **Step 1: Failing tests.**
  - `storyWriteDto` test: wire dates UTC midnight, `'year'` → `DatePrecision.year`, null field stays null, `placeId: ''` → `clearPlace: true, placeId: null`, person list → `UuidValue`s, null stays null.
  - `downloadFirstThumbs` keeps gateway test, adds: story with no photo returns `{}` without touching server.
  - Live (`stories_live_test.dart`, one user): createDraft (undated, `allowUndated: true`) → updateDraft (date, title, body, place, person) → autosaveDraft true → listMyDrafts contains it → getStory → linkPerson repeat no-op → publish → autosaveDraft false → getPublished / getPublishedOrigin / listPublished / listLatestPublished contain it → storiesForPerson card (title, `whenLabel`, place, photo thumb bytes) → downloadFirstThumbs bytes → discard → getPublished null. Plus: createDraft same id twice = one story (server idempotency); createDraft with no date and no `allowUndated` throws `ArgumentError` before call.
- [ ] **Step 2:** run → FAIL (`storyWriteDto` missing; live: Supabase not initialized).
- [ ] **Step 3: Implement.**
  - Imports: server client as `server`, `serverClient`, `withServerErrors`, `wire.dart`. Remove `supabase_flutter`, `supabase_errors.dart`.
  - Delete `isDuplicateStoryKey`, `createOrUpdateExisting`, `_storySelect`, `_publishedSelect`, `_replacePeople`, `_applyStoryWrite`, `_date`, `_parseDate`, `_storyStatusFrom`, and `photos:` constructor param (server deletes photo blobs on discard).
  - `StoriesApi({server.Client? client})`; `server.Client get _client => _injected ?? serverClient;`.
  - Every method = one `withServerErrors(() => _client.story.<method>(...))` call, mapped via `Story.fromDto`. `createDraft` keeps client `ensureValidDraftSave` check when `!allowUndated`, passes `allowUndated:` explicitly. `getPublished` + `getPublishedOrigin` both call `story.getPublished`. `listLatestPublished` passes `withinDays` + `limit`; server clock sets window (`now` arg only matters to fakes and landing page's own `latestShelf`).
  - `storyWriteDto(...)` (top-level, public for tests) builds `server.StoryWriteDto` from gateway's named fields.
  - `storiesForPerson` = `story.listForPerson` + `downloadFirstThumbs(stories, null, client: _client)`.
  - `downloadFirstThumbs(stories, photos, {client})`: first key per story, deduped. With `PhotosGateway` (tests), `downloadBytes` per key; without, one `media.getMany` call. Failure leaves thumbs blank.
  - `gateway_errors_test.dart`: delete `StoriesApi.linkPerson`, `StoriesApi.linkPerson duplicates`, `StoriesApi.discard` cases (Supabase paths).
- [ ] **Step 4:** `flutter test` + `just test-live` pass.
- [ ] **Step 5:** commit `feat(client): StoriesApi on the story endpoint`.

### Task 3: Search on `story.search` and `story.facets`

**Files:** Modify `lib/data/search_api.dart`, `lib/features/search/search_page.dart`, `lib/core/router/app_router.dart`; Delete `lib/features/stories/timeframe_chips.dart`; remove `Story.fromJson` + helpers from `stories_api.dart`. Test `test/search_api_test.dart`, `test/search_page_test.dart`, `test/new_story_capture_test.dart` (its `DecadeRange`/`decadeChips` tests), `test/live/search_live_test.dart`.

- [ ] **Step 1: Failing tests.**
  - `searchDto(SearchRequest(...))` maps family/person/place ids → `UuidValue`, range → wire dates, decades as given, each `SearchSort` → server value.
  - `SearchFacets.fromDto` keeps server order: decades, people `(id, name)`, places `(id, label)`.
  - `decadeChipLabel` stays.
  - `search_page_test`: fake gateway returns `List<Story>` + `SearchFacets` (1980s, 1990s; Clara; Back Porch). Idle state suggests exactly facet chips. Decade picker lists only facet decades (no 1950s). `_People.listPeople` no longer called; `_Places` deleted.
  - Live: two published stories, different decades, different people/places. `facets` lists both decades, both people, both places with ids. `search` by text tier, person (AND), place, decade, `recentlyAdded` sort returns expected ids. Non-member user gets `AppException(forbidden)`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implement.**
  - `SearchGateway { Future<List<Story>> search(SearchRequest); Future<SearchFacets> facets(String familyId); }`. `SearchRecord` goes (`Story.placeAddress` already carries address).
  - Delete `filterSearchRecords`, `searchRecordFromRow`, `searchTextMatches`, `timeframeOverlaps`, relevance helpers, `decadeLabelFor`, `decadeBounds`, `decadePickerFirstYear`/`LastYear`, and `decadeStartYear` in `stories_api.dart` (no caller; timeline has own in `timeline_zoom.dart`).
  - `SearchPage`: `SearchFacets _facets` replaces `_people`, `_places`, `_storyDecades`. Boot loads `facets(familyId)` (failure = existing "Try again"). Picker, suggestion, chip-label code read `_facets`. Chip widgets, keys, copy unchanged; decade label stays `'${year}s'`. `placesApi` removed from page and `app_router.dart`.
  - Delete `timeframe_chips.dart`.
- [ ] **Step 4:** pass.
- [ ] **Step 5:** commit `feat(client): search on story.search and facets`.

### Task 4: Drop `StoryDatePrecision.decade` (D9)

**Files:** Modify `lib/data/stories_api.dart` (`StoryDatePrecision`, `_profileWhen`), `lib/features/stories/story_date.dart`, `lib/features/stories/new_story_page.dart`, `lib/features/settings/settings_page.dart:926`. Test `test/story_date_test.dart`, `test/all_stories_logic_test.dart` (U-04), `test/new_story_capture_test.dart`.

- [ ] **Step 1: Tests.**
  - `story_date_test`: decade round-trip + label cases deleted. `compareStories` orders `year` < `month` < `day` (decade row goes).
  - U-04 compares `year` row vs later `day` row.
  - `new_story_capture_test`: delete "legacy decade opens empty and cannot save". "published decade edit can save without replacing the date" → "a whole-year story opens with its year in the box" (year box `1980`, Save changes enabled). "edit saves a changed year with month and day" starts from `year` row.
- [ ] **Step 2:** remove enum value; analyzer lists every switch + caller.
- [ ] **Step 3: Implement.**
  - `enum StoryDatePrecision { year, month, day }`.
  - `StoryDate` loses `legacyDecade` + decade switch arms.
  - `new_story_page.dart` loses `_loadedLegacy` + `_shouldWriteDate`: loaded date always fills boxes; draft saves when boxes hold date.
  - `settings_page._storedBirth` keeps only null check.
- [ ] **Step 4:** pass.
- [ ] **Step 5:** commit `refactor(client): drop decade precision (D9)`.

### Task 5: `ServerTimelineLive`

**Files:** Modify `lib/data/timeline_live.dart`, `lib/features/timeline/timeline_page.dart:85`. Test `test/timeline_live_test.dart` (new), `test/timeline_page_test.dart`, `test/live/server_timeline_live_test.dart`.

- [ ] **Step 1: Failing tests** (`testWidgets` for fake time; `_FakeClient extends server.Client` overrides `live` with `_FakeLiveEndpoint extends server.EndpointLive` whose `watchFamily`/`watchStory` hand out `StreamController`s):
  - `timelineEventMatters`: other family → false; draft story event → false; published story, deleted story, photo, note → true.
  - Two matching events 50 ms apart → one `onChange`, 200 ms after second.
  - Non-matching event → no `onChange`.
  - `ServerpodClientUnauthorized` on stream → nothing thrown; resubscribes after 1 s, then 2 s after second error; event resets delay to 1 s; `onDone` also resubscribes.
  - `dispose` cancels subscription + pending timers; no resubscribe after.
  - `watch` same family twice opens one stream; other family closes first.
  - `watchStory` refreshes on any event of its story.
  - Live: member watches family, publishes story → `onChange` within 10 s; `watchStory` on published story fires after update.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implement.**

```dart
bool timelineEventMatters({
  required String familyId,
  required server.LiveEventDto event,
}) {
  if (event.familyId.toString() != familyId) return false;
  if (event.kind == server.LiveKind.story &&
      !event.deleted &&
      event.storyStatus != null &&
      event.storyStatus != server.StoryStatus.published) {
    return false;
  }
  return true;
}
```

`ServerTimelineLive({server.Client? client})` holds one `_LiveFeed` per kind. `_LiveFeed` listens with `cancelOnError: true`. On error or done, reopens after current delay (1 s doubling to 30 s); any event resets delay. Synchronous throw on open counts as error. `close()` cancels subscription + both timers. `SupabaseTimelineLive` stays for reader with private copy of old row filter. `TimelinePage._live` defaults to `ServerTimelineLive()`.
- [ ] **Step 4:** pass.
- [ ] **Step 5:** commit `feat(client): ServerTimelineLive on live.watchFamily/watchStory`.

### Task 6: Gate

From worktree root:
- `mise exec -- dart format --output=none --set-exit-if-changed apps/tell_me_a_story/lib apps/tell_me_a_story/test` → 0 changed.
- `cd apps/tell_me_a_story && mise exec -- flutter analyze` → ≤23 issues.
- `mise exec -- flutter test` → all pass.
- `mise exec -- just test-live` → all live files pass vs shared `just server`.

Then update plan to what landed, commit `docs: Phase 4c plan as landed`.

## Handoffs

- **4e:** `story_reader_page.dart:226` swaps `SupabaseTimelineLive()` for `ServerTimelineLive()` (one line; `TimelineLive` unchanged). After, `SupabaseTimelineLive` has no caller, gets deleted (4e or 4z).
- **4d:** `settings_page.dart:926` loses `|| date.legacyDecade` here. `person_date_field.dart` still uses `storyDatePrecisionFrom` (unchanged).
- **4z:** `search_page_test` no longer builds `Person`/`Place` fixtures, so 4d field removals don't touch it.
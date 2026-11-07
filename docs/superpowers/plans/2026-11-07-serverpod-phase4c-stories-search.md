# Phase 4c: Stories, Search, Timeline Live — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `StoriesApi`, `SearchApi` and the timeline's live feed talk to the Serverpod server instead of Supabase, and the dropped `decade` precision (D9) leaves the app.

**Architecture:** Each gateway keeps its class name and interface (`SearchGateway` gains `facets`; that is 4c's interface change). Gateways read the generated client lazily (`_injected ?? serverClient`) and wrap every `Future` call in `withServerErrors`. DTO → domain mapping is a `fromDto` factory next to the domain class. `ServerTimelineLive` replaces `SupabaseTimelineLive` on the timeline; the reader (`story_reader_page.dart`, slice 4e) swaps with one line because `TimelineLive` is unchanged.

**Tech Stack:** Flutter 3.47.7, the generated `tell_me_a_story_client` (Serverpod 4.1.1), `flutter_test`, just.

**Scope contract:** the Phase 4 index, row "4c Stories, search, timeline live". Server behaviour is `apps/server/lib/src/endpoints/story_endpoint.dart`, `stories/story_search.dart`, `endpoints/live_endpoint.dart`.

All commands run from `apps/tell_me_a_story` unless a step says otherwise. `flutter`/`dart`/`just` run through `mise exec --`.

---

## File map

| Path | Responsibility |
|---|---|
| `lib/data/stories_api.dart` | `Story.fromDto`, `storyWriteDto`, `StoriesApi` on `story.*`, `downloadFirstThumbs` on `media.getMany`; `StoryDatePrecision` without `decade` |
| `lib/data/search_api.dart` | `searchDto`, `SearchFacets.fromDto`, `SearchGateway.facets`, `SearchApi` on `story.search` / `story.facets`; `search` returns `List<Story>` |
| `lib/data/timeline_live.dart` | `timelineEventMatters(LiveEventDto)`, `ServerTimelineLive` (debounce, backoff resubscribe); `SupabaseTimelineLive` kept for the reader until 4e swaps |
| `lib/features/search/search_page.dart` | person, place and decade chips from facets; no `placesApi` |
| `lib/features/stories/timeframe_chips.dart` | deleted (fixed 1900–2020 decades; `TimeframeChips` had no caller since M13) |
| `lib/features/stories/story_date.dart` | no `legacyDecade` |
| `lib/features/timeline/timeline_page.dart` | `ServerTimelineLive()` default |
| `lib/features/stories/new_story_page.dart` | legacy decade load/save paths removed (D9 switch fallout) |
| `lib/features/settings/settings_page.dart` | `_storedBirth` drops its `legacyDecade` check (one line, D9 fallout; 4d owns the file) |
| `lib/core/router/app_router.dart` | `SearchPage` no longer takes `placesApi` (one line) |
| `test/stories_api_test.dart`, `all_stories_logic_test.dart`, `drafts_page_test.dart` | `fromDto` tests replace `fromJson` fixtures; duplicate-key and select-scan tests deleted |
| `test/search_api_test.dart`, `search_page_test.dart` | `searchDto` / `SearchFacets.fromDto` tests; page fake serves facets |
| `test/timeline_live_test.dart` | `timelineEventMatters` and `ServerTimelineLive` (fake `EndpointLive`) |
| `test/timeline_page_test.dart` | its `timelineEventMatters` case moves to `timeline_live_test.dart` |
| `test/story_date_test.dart`, `new_story_capture_test.dart` | decade cases deleted or moved to `year` |
| `test/gateway_errors_test.dart` | its `StoriesApi` groups deleted with the Supabase paths they covered |
| `test/live/support/story_fixtures.dart` | `seedFamily` (family + person + place via the raw client) |
| `test/live/stories_live_test.dart`, `search_live_test.dart`, `server_timeline_live_test.dart` | live round trips |

Fakes of interfaces this slice changes: `SearchGateway` has one fake, `_Search` in `test/search_page_test.dart`. `StoriesGateway` and `TimelineLive` are unchanged, so their fakes stay.

---

### Task 1: `Story.fromDto`

**Files:** Modify `lib/data/stories_api.dart` (class `Story`), Test `test/stories_api_test.dart`, `test/all_stories_logic_test.dart`, `test/drafts_page_test.dart`.

- [ ] **Step 1: Failing tests.** In `stories_api_test.dart` replace the `Story.fromJson` cases with `fromDto` cases that build DTOs directly:

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

plus: an undated draft (`dateStart: null, precision: null` → null dates, `StoryStatus.draft`, default `day`); people (`personIds`, `people`, `personNames`, `personUserIds` only for a linked person; blank names dropped from `people`/`personNames` but kept in `personIds`); trimmed `placeLabel`/`placeAddress`/`authorName` with blank → null; `photoPaths` = photo keys in server order and `photoCount`. `all_stories_logic_test` U-01 becomes a `fromDto` test of address and person user ids; `drafts_page_test` and `compareStories` fixtures use the `Story(...)` constructor.

- [ ] **Step 2:** `flutter test test/stories_api_test.dart` → FAIL (`fromDto` isn't defined).
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

`_trimmed(String?)` returns the trimmed value or null when blank. The server already orders `photos` (sortOrder, createdAt, id) and resolves each to its edited key, so the client does not re-sort.

- [ ] **Step 4:** the three test files pass.
- [ ] **Step 5:** commit `feat(client): Story.fromDto`.

### Task 2: `StoriesApi` on the server

**Files:** Modify `lib/data/stories_api.dart`; Test `test/stories_api_test.dart`, `test/gateway_errors_test.dart`, `test/live/support/story_fixtures.dart`, `test/live/stories_live_test.dart`.

- [ ] **Step 1: Failing tests.**
  - `storyWriteDto` test: wire dates are UTC midnight, `'year'` → `DatePrecision.year`, a null field stays null, `placeId: ''` → `clearPlace: true, placeId: null`, a person list becomes `UuidValue`s and null stays null.
  - `downloadFirstThumbs` keeps its gateway test, and adds: a story with no photo returns `{}` without touching a server.
  - Live (`stories_live_test.dart`, one user): createDraft (undated, `allowUndated: true`) → updateDraft (date, title, body, place, person) → autosaveDraft true → listMyDrafts contains it → getStory → linkPerson repeat is a no-op → publish → autosaveDraft false → getPublished / getPublishedOrigin / listPublished / listLatestPublished contain it → storiesForPerson card (title, `whenLabel`, place, photo thumb bytes) → downloadFirstThumbs bytes → discard → getPublished null. Plus: createDraft with the same id twice is one story (server idempotency), and createDraft without a date and without `allowUndated` throws `ArgumentError` before the call.
- [ ] **Step 2:** run them → FAIL (`storyWriteDto` missing; live: Supabase not initialized).
- [ ] **Step 3: Implement.**
  - Imports: the server client as `server`, `serverClient`, `withServerErrors`, `wire.dart`. Remove `supabase_flutter` and `supabase_errors.dart`.
  - Delete `isDuplicateStoryKey`, `createOrUpdateExisting`, `_storySelect`, `_publishedSelect`, `_replacePeople`, `_applyStoryWrite`, `_date`, `_parseDate`, `_storyStatusFrom`, and the `photos:` constructor parameter (the server deletes photo blobs on discard).
  - `StoriesApi({server.Client? client})`; `server.Client get _client => _injected ?? serverClient;`.
  - Every method is one `withServerErrors(() => _client.story.<method>(...))` call, mapped with `Story.fromDto`. `createDraft` keeps the client `ensureValidDraftSave` check when `!allowUndated` and passes `allowUndated:` explicitly. `getPublished` and `getPublishedOrigin` both call `story.getPublished`. `listLatestPublished` passes `withinDays` and `limit`; the server's clock sets the window (the `now` argument only matters to fakes and the landing page's own `latestShelf`).
  - `storyWriteDto(...)` (top-level, public for tests) builds `server.StoryWriteDto` from the gateway's named fields.
  - `storiesForPerson` = `story.listForPerson` + `downloadFirstThumbs(stories, null, client: _client)`.
  - `downloadFirstThumbs(stories, photos, {client})`: the first key of each story, deduplicated. With a `PhotosGateway` (tests), `downloadBytes` per key; without one, one `media.getMany` call. A failure leaves thumbs blank.
  - `gateway_errors_test.dart`: delete the `StoriesApi.linkPerson`, `StoriesApi.linkPerson duplicates` and `StoriesApi.discard` cases (Supabase paths).
- [ ] **Step 4:** `flutter test` and `just test-live` pass.
- [ ] **Step 5:** commit `feat(client): StoriesApi on the story endpoint`.

### Task 3: Search on `story.search` and `story.facets`

**Files:** Modify `lib/data/search_api.dart`, `lib/features/search/search_page.dart`, `lib/core/router/app_router.dart`; Delete `lib/features/stories/timeframe_chips.dart`; remove `Story.fromJson` and its helpers from `stories_api.dart`. Test `test/search_api_test.dart`, `test/search_page_test.dart`, `test/new_story_capture_test.dart` (its `DecadeRange`/`decadeChips` tests), `test/live/search_live_test.dart`.

- [ ] **Step 1: Failing tests.**
  - `searchDto(SearchRequest(...))` maps family/person/place ids to `UuidValue`, the range to wire dates, the decades as given, each `SearchSort` to the server value.
  - `SearchFacets.fromDto` keeps the server order: decades, people `(id, name)`, places `(id, label)`.
  - `decadeChipLabel` stays.
  - `search_page_test`: the fake gateway returns `List<Story>` and a `SearchFacets` (1980s and 1990s; Clara; Back Porch). The idle state suggests exactly the facet chips. The decade picker lists only facet decades (no 1950s). `_People.listPeople` is no longer called, and `_Places` is deleted.
  - Live: two published stories in different decades with different people/places. `facets` lists both decades, both people and both places with their ids. `search` by text tier, person (AND), place, decade and `recentlyAdded` sort returns the expected ids. Another user (not a member) gets `AppException(forbidden)`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implement.**
  - `SearchGateway { Future<List<Story>> search(SearchRequest); Future<SearchFacets> facets(String familyId); }`. `SearchRecord` goes (`Story.placeAddress` already carries the address).
  - Delete `filterSearchRecords`, `searchRecordFromRow`, `searchTextMatches`, `timeframeOverlaps`, the relevance helpers, `decadeLabelFor`, `decadeBounds`, `decadePickerFirstYear`/`LastYear`, and `decadeStartYear` in `stories_api.dart` (no caller left; the timeline has its own in `timeline_zoom.dart`).
  - `SearchPage`: `SearchFacets _facets` replaces `_people`, `_places` and `_storyDecades`. The boot loads `facets(familyId)` (a failure is the existing "Try again"). The picker, suggestion and chip-label code read `_facets`. Chip widgets, keys and copy are unchanged; the decade label stays `'${year}s'`. `placesApi` is removed from the page and from `app_router.dart`.
  - Delete `timeframe_chips.dart`.
- [ ] **Step 4:** pass.
- [ ] **Step 5:** commit `feat(client): search on story.search and facets`.

### Task 4: Drop `StoryDatePrecision.decade` (D9)

**Files:** Modify `lib/data/stories_api.dart` (`StoryDatePrecision`, `_profileWhen`), `lib/features/stories/story_date.dart`, `lib/features/stories/new_story_page.dart`, `lib/features/settings/settings_page.dart:926`. Test `test/story_date_test.dart`, `test/all_stories_logic_test.dart` (U-04), `test/new_story_capture_test.dart`.

- [ ] **Step 1: Tests.**
  - `story_date_test`: the decade round-trip and label cases are deleted. `compareStories` orders `year` < `month` < `day` (the decade row goes).
  - U-04 compares a `year` row against a later `day` row.
  - `new_story_capture_test`: delete "legacy decade opens empty and cannot save" and "published decade edit can save without replacing the date". "edit saves a changed year with month and day" starts from a `year` row.
- [ ] **Step 2:** remove the enum value and the analyzer lists every switch and caller.
- [ ] **Step 3: Implement.**
  - `enum StoryDatePrecision { year, month, day }`.
  - `StoryDate` loses `legacyDecade` and its decade switch arms.
  - `new_story_page.dart` loses `_loadedLegacy` and `_shouldWriteDate`: a loaded date always fills the boxes, and a draft saves when the boxes hold a date.
  - `settings_page._storedBirth` keeps only its null check.
- [ ] **Step 4:** pass.
- [ ] **Step 5:** commit `refactor(client): drop decade precision (D9)`.

### Task 5: `ServerTimelineLive`

**Files:** Modify `lib/data/timeline_live.dart`, `lib/features/timeline/timeline_page.dart:85`. Test `test/timeline_live_test.dart` (new), `test/timeline_page_test.dart`, `test/live/server_timeline_live_test.dart`.

- [ ] **Step 1: Failing tests** (`testWidgets` for fake time; `_FakeClient extends server.Client` overrides `live` with a `_FakeLiveEndpoint extends server.EndpointLive` whose `watchFamily`/`watchStory` hand out `StreamController`s):
  - `timelineEventMatters`: another family → false; a draft story event → false; a published story, a deleted story, a photo and a note → true.
  - Two matching events 50 ms apart → one `onChange`, 200 ms after the second.
  - A non-matching event → no `onChange`.
  - `ServerpodClientUnauthorized` on the stream → nothing thrown; resubscribes after 1 s, then 2 s after a second error; an event resets the delay to 1 s; `onDone` also resubscribes.
  - `dispose` cancels the subscription and pending timers; no resubscribe after it.
  - `watch` with the same family twice opens one stream; another family closes the first.
  - `watchStory` refreshes on any event of its story.
  - Live: a member watches the family, publishes a story → `onChange` within 10 s; `watchStory` on a published story fires after an update.
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

`ServerTimelineLive({server.Client? client})` holds one `_LiveFeed` per kind. A `_LiveFeed` listens with `cancelOnError: true`. On error or done it reopens after the current delay (1 s doubling to 30 s), and any event resets the delay. A synchronous throw from opening counts as an error. `close()` cancels the subscription and both timers. `SupabaseTimelineLive` stays for the reader with a private copy of its old row filter. `TimelinePage._live` defaults to `ServerTimelineLive()`.
- [ ] **Step 4:** pass.
- [ ] **Step 5:** commit `feat(client): ServerTimelineLive on live.watchFamily/watchStory`.

### Task 6: Gate

From the worktree root:
- `mise exec -- dart format --output=none --set-exit-if-changed apps/tell_me_a_story/lib apps/tell_me_a_story/test` → 0 changed.
- `cd apps/tell_me_a_story && mise exec -- flutter analyze` → at most 23 issues.
- `mise exec -- flutter test` → all pass.
- `mise exec -- just test-live` → all live files pass against the shared `just server`.

Then update this plan to what landed and commit `docs: Phase 4c plan as landed`.

## Handoffs

- **4e:** `story_reader_page.dart:226` swaps `SupabaseTimelineLive()` for `ServerTimelineLive()` (one line; `TimelineLive` is unchanged). After that, `SupabaseTimelineLive` has no caller and is deleted (4e or 4z).
- **4d:** `settings_page.dart:926` loses `|| date.legacyDecade` here. `person_date_field.dart` still uses `storyDatePrecisionFrom` (unchanged).
- **4z:** `search_page_test` no longer builds `Person`/`Place` fixtures, so 4d's field removals don't touch it.

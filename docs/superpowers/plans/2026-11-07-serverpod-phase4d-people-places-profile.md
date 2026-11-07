# Phase 4d: People, Places, Profile — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `PeopleApi`, `PlacesApi` and `ProfileApi` call the generated Serverpod client instead of Supabase, and Settings shows the account email read-only (D1).

**Architecture:** Each gateway keeps its class name and interface (except the two interface changes this slice owns: `ProfileGateway.updateEmail` and `Place.familyId` go). Constructors become `XxxApi({server.Client? client})` with the lazy `serverClient` fallback; every call is wrapped in `withServerErrors`. DTO → domain mapping is a `fromDto` factory next to each domain class, using `wire.dart` for dates and precision. Blobs (person pictures, own avatar) are read with `media.get` and written inline as `ByteData` after the existing 512 px / q80 JPEG compression.

**Tech Stack:** Flutter 3.47.7, `tell_me_a_story_client` (Serverpod 4.1.1), flutter_test, `just test-live` against the shared `just server`.

**Index row:** `2026-11-07-serverpod-phase4-client-cutover.md` §"4d People, places, profile". Conventions there are binding.

---

## File map

| File | Responsibility | Change |
|---|---|---|
| `apps/tell_me_a_story/lib/data/people_api.dart` | `Person`, `PersonProfile`, `PeopleGateway`, `PeopleApi` | `fromDto` factories; `relationship`, `createdBy`, `fromJson`, `personProfileFromRpc`, bucket/path helpers, `personDateFromJson`, `personDateIso`, `avatarsBucketName` deleted; `PeopleApi` on `people.*` and `media.get` |
| `apps/tell_me_a_story/lib/data/places_api.dart` | `Place`, `PlacesGateway`, `PlacesApi` | `Place.familyId` and `fromJson` removed, `Place.fromDto`; `placeInput()` (a `PlaceInputDto`) replaces `buildPlaceInsert`; `PlacesApi` on `place.*` |
| `apps/tell_me_a_story/lib/data/profile_api.dart` | `OwnProfile`, `BirthVisibility`, `ProfileGateway`, `ProfileApi` | `OwnProfile.fromDto`; `BirthVisibility.toServer/fromServer` replace `toWire/fromWire`; `updateEmail`, `EmailUpdate`, `ProfilePatch`, `AvatarUpload`, the bucket/path helpers and the Supabase seams deleted; `ProfileApi` on `profile.*` and `media.get` |
| `apps/tell_me_a_story/lib/features/settings/settings_page.dart` | Settings | email field `readOnly`, not part of the dirty check, no `updateEmail` |
| `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart` | (4e owns) | only the `person.relationship` block (old lines 1363-1370) is deleted so the branch compiles |
| `apps/tell_me_a_story/test/people_api_test.dart` | unit | `fromJson`/`personProfileFromRpc`/PostgREST-stub/self-testing fake groups → `fromDto` tests; `ensureValidPersonCreate` kept |
| `apps/tell_me_a_story/test/places_api_test.dart` | unit | `fromJson`/`buildPlaceInsert`/self-testing fake groups → `fromDto` and `placeInput` tests; `ensureValidPlaceCreate` kept |
| `apps/tell_me_a_story/test/profile_api_test.dart` | unit | seam tests → `OwnProfile.fromDto` + `BirthVisibility` mapping + compress-before-network test |
| `apps/tell_me_a_story/test/settings_page_test.dart`, `settings_guard_test.dart` | widget | D1: email tests rewritten to "field is read-only"; `updateEmail` dropped from the `_Profile` fakes |
| `apps/tell_me_a_story/test/m14_3_dob_passed_away_test.dart` | widget | `updateEmail` dropped from `_Profile` |
| every test building `Person(relationship:, createdBy:)` or `Place(familyId:)` | fixtures | arguments removed; fakes that filtered by `Place.familyId` stop filtering (each test seeds one family) |
| `apps/tell_me_a_story/test/live/people_live_test.dart` | live | create/update with picture, tree list with birth coarsening, markPassedAway, the rest of `PeopleGateway` |
| `apps/tell_me_a_story/test/live/places_live_test.dart` | live | create, markUsed, favorite, recents, list, find, get |
| `apps/tell_me_a_story/test/live/profile_live_test.dart` | live | loadOwn, saveName, saveAccount, avatar save/download/clear |

Fake inventory (`rg -n "implements \w+Gateway|extends \w+Gateway" apps/tell_me_a_story/test`): `ProfileGateway` — `m14_3_dob_passed_away_test`, `settings_guard_test`, `settings_page_test`. `PlacesGateway` fakes keep their signatures; only their `Place(familyId:)` fixtures change. `PeopleGateway` keeps its signatures.

---

### Task 1: Places on the server

**Files:** Modify `lib/data/places_api.dart`; test `test/places_api_test.dart`; fixtures in `edit_story_guard_test`, `new_story_capture_test`, `new_story_guard_test`, `new_story_shell_test`, `place_picker_modal_test`, `search_page_test`, `start_timeline_test`, `story_reader_page_test`.

- [ ] **Step 1: failing test** — replace the `Place.fromJson`, `buildPlaceInsert` and `FakePlacesGateway` groups with:

```dart
group('Place.fromDto', () {
  test('maps every field and keeps label/address distinct', () {
    final used = DateTime.utc(2026, 9, 27, 12);
    final place = Place.fromDto(
      server.PlaceDto(
        id: server.UuidValue.fromString(_placeId),
        treeId: server.UuidValue.fromString(_treeId),
        label: 'Central Park',
        address: 'New York, NY',
        lat: 40.78,
        lng: -73.96,
        mapboxPlaceId: 'poi.1',
        isFavorite: true,
        lastUsedAt: used,
      ),
    );
    expect(place.id, _placeId);
    // ...label, address, lat, lng, mapboxPlaceId, isFavorite, lastUsedAt
  });
});
group('placeInput', () {
  test('trims label and address and keeps them separate', () { ... });
});
```

- [ ] **Step 2:** `flutter test test/places_api_test.dart` → compile FAIL (`Place.fromDto`, `placeInput` undefined).
- [ ] **Step 3: implement**

```dart
factory Place.fromDto(server.PlaceDto dto) => Place(
  id: dto.id.toString(),
  label: dto.label,
  address: dto.address,
  lat: dto.lat,
  lng: dto.lng,
  mapboxPlaceId: dto.mapboxPlaceId,
  isFavorite: dto.isFavorite,
  lastUsedAt: dto.lastUsedAt,
);

server.PlaceInputDto placeInput({required String label, required String address,
    required double lat, required double lng, String? mapboxPlaceId, bool isFavorite = false}) =>
  server.PlaceInputDto(label: label.trim(), address: address.trim(), lat: lat, lng: lng,
    mapboxPlaceId: mapboxPlaceId, isFavorite: isFavorite);

class PlacesApi implements PlacesGateway {
  PlacesApi({server.Client? client}) : _injected = client;
  final server.Client? _injected;
  server.Client get _client => _injected ?? serverClient;
  // listPlaces → place.list, listFavorites → place.favorites,
  // listRecents → place.recents(limit: limit), createPlace → ensureValidPlaceCreate
  // then place.create(familyId, placeInput(...)), markUsed, setFavorite,
  // findByMapboxPlaceId → place.findByMapboxId, getPlace → place.get.
}
```

  Remove `familyId:` from every `Place(...)` fixture; the fakes in `place_picker_modal_test` drop their `p.familyId == familyId` filters.
- [ ] **Step 4:** `flutter test test/places_api_test.dart test/place_picker_modal_test.dart` → PASS.
- [ ] **Step 5:** commit `feat(client): places gateway on the server`.

### Task 2: Places live test

`test/live/places_live_test.dart`: sign in, `family.createRoot`, `createPlace` (trimmed, `lastUsedAt` set), duplicate Mapbox id returns the same place, `setFavorite` → `listFavorites`, `markUsed` → `listRecents` first, `listPlaces` by label, `findByMapboxPlaceId`, `getPlace`. Run `just test-live` → PASS. Commit `test(client): places live test`.

### Task 3: People on the server

**Files:** `lib/data/people_api.dart`, `lib/features/stories/story_reader_page.dart` (relationship block only), `test/people_api_test.dart`, Person fixtures.

- [ ] **Step 1: failing test** — `Person.fromDto` maps `homeFamilyId` → `familyId`, `deathDate` → `passingDate` (local calendar day), precisions to `year/month/day`, `avatarKey` → `avatarPath`, `userId` to string; `PersonProfile.fromDto` likewise with `isLinked`.
- [ ] **Step 2:** compile FAIL.
- [ ] **Step 3: implement** `Person.fromDto`, `PersonProfile.fromDto` (dates through `fromWireDate`, precision through `precisionName`), and `PeopleApi`:
  - `listPeople` → `people.listFamily`; `listTreePeople` → `people.listTree`;
  - `createPerson` → `people.create(familyId, PersonWriteDto(name, writeAbout/about, writeEmail/email, writePassedAway: true, …), picture)`;
  - `updatePerson` → `people.update(personId, PersonWriteDto(... clearPicture: clearing), picture)`;
  - `personForEdit` → `people.forEdit`; `personProfile` → `people.profile`;
  - `listUnlinkedPeople` → `people.listUnlinked`; `isHomeFamilySteward` → `people.isHomeFamilySteward`; `markPassedAway` → `people.markPassedAway`;
  - `pictureBytes` → `media.get(path)`, null for no path or no blob;
  - pictures: `compressStoryPhoto(bytes, maxEdge: 512, quality: 80)` then `ByteData.sublistView(compressed.bytes)` inline.
  Remove `relationship:`/`createdBy:` from every fixture and delete the reader's relationship `Text` block.
- [ ] **Step 4:** `flutter test` → PASS. **Step 5:** commit `feat(client): people gateway on the server`.

### Task 4: People live test

`test/live/people_live_test.dart`: create with a real JPEG picture → `pictureBytes` returns JPEG bytes; update (about, email, clear picture); `listPeople`/`listTreePeople`; a second user who joined by invite and set a birth with `birthVisibility: year` is seen by the owner with year precision only; `markPassedAway` on that linked person; `personForEdit`, `personProfile`, `listUnlinkedPeople`, `isHomeFamilySteward`. Commit `test(client): people live test`.

### Task 5: Profile on the server + D1

**Files:** `lib/data/profile_api.dart`, `lib/features/settings/settings_page.dart`, `test/profile_api_test.dart`, `test/settings_page_test.dart`, `test/settings_guard_test.dart`, `test/m14_3_dob_passed_away_test.dart`.

- [ ] **Step 1: failing tests**
  - `profile_api_test`: `OwnProfile.fromDto` (id ← `authUserId`, `avatarPath` ← `avatarKey`, birth day + precision, visibility); `BirthVisibility.toServer/fromServer` round-trip for all four values; `saveAvatar` with undecodable bytes throws before any server call (`ProfileApi(client: Client('http://unused/'))`).
  - `settings_page_test`: replace "a changed address calls updateEmail…" and "a blank email still saves the name" with `the email field is read-only` (`TextField.readOnly` is true, and `enterText` leaves the stored email).
  - `settings_guard_test`: replace "clean after a saved email change" with "email field never makes the page dirty".
- [ ] **Step 2:** FAIL (fromDto/toServer undefined; field editable).
- [ ] **Step 3: implement** `ProfileApi({server.Client? client})`: `loadOwn` → null when not signed in, else `profile.me`; `saveName`; `saveAccount` (`toWireDate`, `precisionFromName`, `toServer()`); `saveAvatar` compresses then `profile.saveAvatar(ByteData)` and returns the key; `clearAvatar`; `downloadAvatar` → `media.get`. Delete `updateEmail` from the interface and the three fakes. Settings: `readOnly: true` on `settings-email`, `_loadedEmail` and the `updateEmail` branch removed.
- [ ] **Step 4:** PASS. **Step 5:** commit `feat(client): profile gateway on the server; email read-only (D1)`.

### Task 6: Profile live test

`test/live/profile_live_test.dart`: `loadOwn` returns the signed-in email; `saveName`; `saveAccount` with birth `month` + `yearMonth` + about round-trips; `saveAvatar` of a 1200 px JPEG returns a key that `downloadAvatar` reads back ≤ 512 px; `clearAvatar` clears it. Commit `test(client): profile live test`.

### Task 7: Gate

Run from the worktree: `dart format --output=none --set-exit-if-changed apps/tell_me_a_story/lib apps/tell_me_a_story/test`, `flutter analyze` (≤ 23), `flutter test`, `just test-live`. Update this plan with what landed and commit `docs: Phase 4d plan as landed`.

# Phase 4d: People, Places, Profile — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `PeopleApi`, `PlacesApi`, `ProfileApi` call generated Serverpod client, not Supabase. Settings shows account email read-only (D1).

**Architecture:** Each gateway keeps class name + interface, except two interface changes this slice owns: `ProfileGateway.updateEmail` and `Place.familyId` removed. Constructors become `XxxApi({server.Client? client})` with lazy `serverClient` fallback. Every call wrapped in `withServerErrors`. DTO → domain mapping = `fromDto` factory beside each domain class, using `wire.dart` for dates + precision. Blobs (person pictures, own avatar) read via `media.get`, written inline as `ByteData` after existing 512 px / q80 JPEG compression.

**Tech Stack:** Flutter 3.47.7, `tell_me_a_story_client` (Serverpod 4.1.1), flutter_test, `just test-live` against shared `just server`.

**Index row:** `2026-11-07-serverpod-phase4-client-cutover.md` §"4d People, places, profile". Its conventions binding.

---

## File map

| File | Responsibility | Change |
|---|---|---|
| `apps/tell_me_a_story/lib/data/people_api.dart` | `Person`, `PersonProfile`, `PeopleGateway`, `PeopleApi` | `fromDto` factories. Delete `relationship`, `createdBy`, `fromJson`, `personProfileFromRpc`, bucket/path helpers, `personDateFromJson`, `personDateIso`, `avatarsBucketName`. `PeopleApi` on `people.*` + `media.get` |
| `apps/tell_me_a_story/lib/data/places_api.dart` | `Place`, `PlacesGateway`, `PlacesApi` | Remove `Place.familyId` + `fromJson`; add `Place.fromDto`. `placeInput()` (a `PlaceInputDto`) replaces `buildPlaceInsert`. `PlacesApi` on `place.*` |
| `apps/tell_me_a_story/lib/data/profile_api.dart` | `OwnProfile`, `BirthVisibility`, `ProfileGateway`, `ProfileApi` | `OwnProfile.fromDto`. `BirthVisibility.toServer/fromServer` replace `toWire/fromWire`. Delete `updateEmail`, `EmailUpdate`, `ProfilePatch`, `AvatarUpload`, bucket/path helpers, Supabase seams. `ProfileApi` on `profile.*` + `media.get` |
| `apps/tell_me_a_story/lib/features/settings/settings_page.dart` | Settings | Email field `readOnly`, out of dirty check, no `updateEmail` |
| `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart` | (4e owns) | Only delete `person.relationship` block (old lines 1363-1370) so branch compiles |
| `apps/tell_me_a_story/test/people_api_test.dart` | unit | `fromJson`/`personProfileFromRpc`/PostgREST-stub/self-testing fake groups → `fromDto` tests; keep `ensureValidPersonCreate` |
| `apps/tell_me_a_story/test/places_api_test.dart` | unit | `fromJson`/`buildPlaceInsert`/self-testing fake groups → `fromDto` + `placeInput` tests; keep `ensureValidPlaceCreate` |
| `apps/tell_me_a_story/test/profile_api_test.dart` | unit | Seam tests → `OwnProfile.fromDto` + `BirthVisibility` mapping + compress-before-network test |
| `apps/tell_me_a_story/test/settings_page_test.dart`, `settings_guard_test.dart` | widget | D1: email tests rewritten to "field is read-only"; drop `updateEmail` from `_Profile` fakes |
| `apps/tell_me_a_story/test/m14_3_dob_passed_away_test.dart` | widget | Drop `updateEmail` from `_Profile` |
| every test building `Person(relationship:, createdBy:)` or `Place(familyId:)` | fixtures | Remove args. Fakes filtering by `Place.familyId` stop filtering (each test seeds one family) |
| `apps/tell_me_a_story/test/live/people_live_test.dart` | live | Create/update with picture, tree list with birth coarsening, markPassedAway, rest of `PeopleGateway` |
| `apps/tell_me_a_story/test/live/places_live_test.dart` | live | create, markUsed, favorite, recents, list, find, get |
| `apps/tell_me_a_story/test/live/profile_live_test.dart` | live | loadOwn, saveName, saveAccount, avatar save/download/clear |

Fake inventory (`rg -n "implements \w+Gateway|extends \w+Gateway" apps/tell_me_a_story/test`): `ProfileGateway` — `m14_3_dob_passed_away_test`, `settings_guard_test`, `settings_page_test`. `PlacesGateway` fakes keep signatures; only `Place(familyId:)` fixtures change. `PeopleGateway` keeps signatures.

---

### Task 1: Places on the server

**Files:** Modify `lib/data/places_api.dart`; test `test/places_api_test.dart`; fixtures in `edit_story_guard_test`, `new_story_capture_test`, `new_story_guard_test`, `new_story_shell_test`, `place_picker_modal_test`, `search_page_test`, `start_timeline_test`, `story_reader_page_test`.

- [ ] **Step 1: failing test** — replace `Place.fromJson`, `buildPlaceInsert`, `FakePlacesGateway` groups with:

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

  Remove `familyId:` from every `Place(...)` fixture. Fakes in `place_picker_modal_test` drop `p.familyId == familyId` filters.
- [ ] **Step 4:** `flutter test test/places_api_test.dart test/place_picker_modal_test.dart` → PASS.
- [ ] **Step 5:** commit `feat(client): places gateway on the server`.

### Task 2: Places live test

`test/live/places_live_test.dart`: sign in, `family.createRoot`, `createPlace` (trimmed, `lastUsedAt` set), duplicate Mapbox id → same place, `setFavorite` → `listFavorites`, `markUsed` → `listRecents` first, `listPlaces` by label, `findByMapboxPlaceId`, `getPlace`. Run `just test-live` → PASS. Commit `test(client): places live test`.

### Task 3: People on the server

**Files:** `lib/data/people_api.dart`, `lib/features/stories/story_reader_page.dart` (relationship block only), `test/people_api_test.dart`, Person fixtures.

- [ ] **Step 1: failing test** — `Person.fromDto` maps `homeFamilyId` → `familyId`, `deathDate` → `passingDate` (local calendar day), precisions → `year/month/day`, `avatarKey` → `avatarPath`, `userId` → string. `PersonProfile.fromDto` same, plus `isLinked`.
- [ ] **Step 2:** compile FAIL.
- [ ] **Step 3: implement** `Person.fromDto`, `PersonProfile.fromDto` (dates via `fromWireDate`, precision via `precisionName`), and `PeopleApi`:
  - `listPeople` → `people.listFamily`; `listTreePeople` → `people.listTree`;
  - `createPerson` → `people.create(familyId, PersonWriteDto(name, writeAbout/about, writeEmail/email, writePassedAway: true, …), picture)`;
  - `updatePerson` → `people.update(personId, PersonWriteDto(... clearPicture: clearing), picture)`;
  - `personForEdit` → `people.forEdit`; `personProfile` → `people.profile`;
  - `listUnlinkedPeople` → `people.listUnlinked`; `isHomeFamilySteward` → `people.isHomeFamilySteward`; `markPassedAway` → `people.markPassedAway`;
  - `pictureBytes` → `media.get(path)`, null if no path or no blob;
  - pictures: `compressStoryPhoto(bytes, maxEdge: 512, quality: 80)` then `ByteData.sublistView(compressed.bytes)` inline.
  Remove `relationship:`/`createdBy:` from every fixture; delete reader's relationship `Text` block.
- [ ] **Step 4:** `flutter test` → PASS. **Step 5:** commit `feat(client): people gateway on the server`.

### Task 4: People live test

`test/live/people_live_test.dart`: create with real JPEG picture → `pictureBytes` returns JPEG bytes; update (about, email, clear picture); `listPeople`/`listTreePeople`; second user joined by invite, birth set with `birthVisibility: year` → owner sees year precision only; `markPassedAway` on that linked person; `personForEdit`, `personProfile`, `listUnlinkedPeople`, `isHomeFamilySteward`. Commit `test(client): people live test`.

### Task 5: Profile on the server + D1

**Files:** `lib/data/profile_api.dart`, `lib/features/settings/settings_page.dart`, `test/profile_api_test.dart`, `test/settings_page_test.dart`, `test/settings_guard_test.dart`, `test/m14_3_dob_passed_away_test.dart`.

- [ ] **Step 1: failing tests**
  - `profile_api_test`: `OwnProfile.fromDto` (id ← `authUserId`, `avatarPath` ← `avatarKey`, birth day + precision, visibility); `BirthVisibility.toServer/fromServer` round-trip all four values; `saveAvatar` with undecodable bytes throws before any server call (`ProfileApi(client: Client('http://unused/'))`).
  - `settings_page_test`: replace "a changed address calls updateEmail…" + "a blank email still saves the name" with `the email field is read-only` (`TextField.readOnly` true; `enterText` leaves stored email).
  - `settings_guard_test`: replace "clean after a saved email change" with "email field never makes the page dirty".
- [ ] **Step 2:** FAIL (fromDto/toServer undefined; field editable).
- [ ] **Step 3: implement** `ProfileApi({server.Client? client})`: `loadOwn` → null if not signed in, else `profile.me`; `saveName`; `saveAccount` (`toWireDate`, `precisionFromName`, `toServer()`); `saveAvatar` compresses then `profile.saveAvatar(ByteData)`, returns key; `clearAvatar`; `downloadAvatar` → `media.get`. Delete `updateEmail` from interface + three fakes. Settings: `readOnly: true` on `settings-email`; remove `_loadedEmail` + `updateEmail` branch.
- [ ] **Step 4:** PASS. **Step 5:** commit `feat(client): profile gateway on the server; email read-only (D1)`.

### Task 6: Profile live test

`test/live/profile_live_test.dart`: `loadOwn` returns signed-in email; `saveName`; `saveAccount` with birth `month` + `yearMonth` + about round-trips; `saveAvatar` of 1200 px JPEG returns key that `downloadAvatar` reads back ≤ 512 px; `clearAvatar` clears it. Commit `test(client): profile live test`.

### Task 7: Gate

Run from worktree: `dart format --output=none --set-exit-if-changed apps/tell_me_a_story/lib apps/tell_me_a_story/test`, `flutter analyze` (≤ 23), `flutter test`, `just test-live`. Update plan with what landed; commit `docs: Phase 4d plan as landed`.

---

## As landed (2026-11-07)

Commits on `feat/p4d-people-places-profile`: `e5d9f7f` plan, `f6ef33b` places, `0f64419` places live, `66f7d3c` people, `8d14ba7` people live, `b7366a1` profile + D1, `872d031` profile live.

- **Gateways:** `PlacesApi`, `PeopleApi`, `ProfileApi` call `place.*`, `people.*`, `profile.*`, `media.get` via `withServerErrors`. `Person.avatarPath`, `PersonProfile.avatarPath`, `OwnProfile.avatarPath` keep names, now hold blob keys. `ProfileApi.loadOwn` returns null when `serverClient.auth.isAuthenticated` false.
- **Deleted code:** `Person.relationship`, `Person.createdBy`, `Person.fromJson`, `PersonProfile.fromJson`, `personProfileFromRpc`, `personAvatarsBucket`, `personAvatarObjectPath`, `personDateFromJson`, `personDateIso`, `avatarsBucketName`; `Place.familyId`, `Place.fromJson`, `buildPlaceInsert`; `ProfileGateway.updateEmail`, `EmailUpdate`, `ProfilePatch`, `AvatarUpload`, `avatarsBucket`, `avatarObjectPath`, `BirthVisibility.toWire/fromWire` (now `toServer/fromServer`).
- **Outside owned files (minimal, for compile):**
  - `lib/features/stories/story_reader_page.dart` (4e): deleted `if ((person.relationship ?? '').trim().isNotEmpty) ...[ … ]` block in `_personChip` (8 lines).
  - `integration_test/e2e_test.dart` + `integration_test/support/preconditions.dart` (4f): `place.familyId` (2 uses) replaced by new `currentE2eFamilyId()` helper in preconditions; `createFavoritePlace` uses it too.
  - `test/gateway_errors_test.dart` (deleted in 4z): its four `PeopleApi` Supabase-error tests deleted.
- **Tests:** unit 723 → 696 (people_api 16→7, places_api 18→7 — self-testing fake groups gone, profile_api 5→4, settings_page 14→13, m14_3 14→13 (wire-string test moved to profile_api round-trip), gateway_errors 13→9). Live +4 (people 2, places 1, profile 1).
- **Gate:** format 0 changed; analyze 15 issues; `flutter test` +696 ~4; `just test-live` +6.
# M3 People + Places — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` after human approval. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Gate:** Plan-only until human approves. Do not write application code until approval.
>
> **On approval:** Copy this plan to `docs/superpowers/plans/2026-09-26-m3-people-places.md` in the implementation PR (or first commit).

**Goal:** Deliver Impl Spec §15 M3 — shared family people + places lists, Mapbox place picker (client public token), favorites/recents — against **local** Supabase. Exit = Bill local smoke.

**Architecture:** Reuse existing `people` / `places` DDL + RLS from M1. Add Flutter PostgREST repositories under `lib/data/`, Mugatu Add Person and Place picker modals under `features/people` and `features/places`, and a **minimal** `/stories/new` shell that hosts those entry points only (full capture text/photos/draft/publish stays **M4**). Mapbox Search via HTTP Geocoding API; map basemap + pin via a thin `PlaceMap` abstraction that works on **iOS and web**.

**Tech Stack (locked):** Flutter 3.x, `supabase_flutter`, PostgREST + RLS, Mapbox public token (`MAPBOX_ACCESS_TOKEN` dart-define), Mapbox Geocoding HTTP + Mapbox-rendered basemap. Secrets via `--dart-define` only.

## Global Constraints

- **SoT precedence:** PRD must/must-not → Mugatu screens/copy → SAD names → Design Doc DDL/RLS/Mapbox → Impl Spec §10 routes/behavior → Client copy & chrome locks for strings.
- **M3 scope only (§15):** Shared lists; Mapbox place picker; favorites/recents. First 10 **#8** (Mapbox public token + place picker).
- **Host decision (locked this session):** Minimal `/stories/new` shell — people chips + place+map entry only. No story body, timeframe, photos. **No Save draft / Publish chrome at all (even disabled).**
- **Timeline entry (approval lock):** `New story` on Timeline is a **smoke entry only** — functional AppBar action → `/stories/new`. Do **not** invent Stitch/Memory Album chrome on Timeline for M3.
- **Add Person (approval lock):** Create requires **relationship**; **email optional** (future invite). Shared **family person** list only — not deceased-only mode, not a public directory.
- **Geocode persist (approval lock):** On Mapbox hit → persist **both** `label` and `address` as separate columns. Do **not** collapse one into the other (e.g. do not write the same string to both unless the API truly returns only one usable string — prefer `text`/`place_name` split: short name → `label`, full `place_name` → `address` when both exist).
- **flutter_map fallback (approval lock):** If used, tiles **must** be Mapbox streets (`mapbox/streets-v12` or equivalent Mapbox style URL with public token). **Forbidden:** OSM / openstreetmap.org tiles.
- **Repo map §3:** Feature folders `features/people/`, `features/places/`, `features/stories/` (stub page only). No new Edge Functions. No schema invention beyond Design Doc columns already migrated.
- **Out of M3:** New Story full capture (M4), drafts list (M4), story_people persistence on publish (M4), search screen (M7), timeline zoom (M6), Resend/cloud staging (Bill / Staging MS).
- **Mapbox CONFLICT (resolved in Impl Spec):** Stitch chrome looks Google-like; **pick Mapbox**. Match pin/favorites/recents behavior.
- **Secrets:** Never commit `.env` or Mapbox tokens. Inject `MAPBOX_ACCESS_TOKEN` via dart-define. No Mapbox secret / server geocode in v1. **`MAPBOX_ACCESS_TOKEN` stays OPEN** until Bill provides a public token — wire the define + failure UX; do not block the PR on live map smoke.
- **Git:** Branch `feat/m03-people-places` from latest `main` in `.worktrees/feat-m03-people-places`. Open PR; do not merge. No `--no-verify`, no force-push.
- **Env rule (Bill 2026-09-26):** Feature MS exit = local smoke. Staging MS is separate and late.

## Preconditions / blockers

| Item | Status at plan time |
|------|---------------------|
| `main` includes M1+M2 (+ auth callback fixes) | Yes — tip `0355282`; local main fast-forwarded |
| `people` / `places` tables + RLS | Already in M1 migrations |
| Flutter SDK | Present (`3.47.5`) |
| Local Supabase ports `5732x` | Per local-dev memory / README |
| Mapbox account + restricted public token | **OPEN (Bill)** — agent implements dart-define wiring; local map smoke needs a real public token from Bill (or waived) |
| Cloud staging | Deferred to Staging MS — local only |

## Spec match (M3)

| Exit criterion (§15 M3) | M3 agent delivery | Status |
|-------------------------|-------------------|--------|
| Shared people list | PostgREST list/create; Add Person pick + create modals | Agent closes |
| Shared places list | PostgREST list/create/update; favorites + `last_used_at` recents | Agent closes |
| Mapbox place picker | Client token; search + basemap pin; persist address/lat/lng/`mapbox_place_id?` | Agent closes locally when token present |
| Favorites / recents | Favorites section (`is_favorite`); recents by `last_used_at` | Agent closes |
| Checks (§14 slice) | `flutter test`; re-run `supabase test db` (existing RLS still green) | Agent closes on local |

**PR title/body stance:** `feat(m03): People + places (Mapbox token OPEN if Bill key missing)` — do not claim Bill smoke closed.

## Mapbox client approach (locked for this plan)

Official `mapbox_maps_flutter` stable **2.x is iOS/Android only**; web support is still prerelease. Spec requires **iOS + web parity**.

**Pick:**

1. **Search / geocode:** HTTP Mapbox Geocoding API v5 with the public token (`http` package). Persist **both** `label` and `address` (approval lock — do not collapse). Prefer feature `text` → `label` and full `place_name` → `address`; center → `lat`/`lng`; feature `id` → `mapbox_place_id`.
2. **Basemap + pin:** Thin `PlaceMap` widget with conditional implementations:
   - **Web:** Mapbox GL JS via `HtmlElementView` / JS interop (public token).
   - **iOS (and other non-web):** `mapbox_maps_flutter` `MapWidget` + point annotation **or**, if iOS compile/Xcode remains blocked on the agent machine, `flutter_map` with **Mapbox streets tiles only** (never OSM).
3. **Failure UX (chrome lock):** `Couldn’t load the map. Check your connection and try again.` + button `Try again`. Do not fake pins.
4. **Token missing:** Treat like Mapbox failure (same locked copy). Do **not** crash app startup solely for empty `MAPBOX_ACCESS_TOKEN` during unit tests; require token for interactive map smoke / document in README.

> Do **not** add a server-side geocode Edge Function. Do **not** ship Google Maps SDK.

## Files to touch

### Create

| Path | Responsibility |
|------|----------------|
| `apps/tell_me_a_story/lib/data/people_api.dart` | `PeopleGateway` + PostgREST list/create for `people` |
| `apps/tell_me_a_story/lib/data/places_api.dart` | `PlacesGateway` + list favorites/recents, create, mark used, toggle favorite |
| `apps/tell_me_a_story/lib/data/mapbox_search.dart` | Geocoding HTTP client; models for search hits |
| `apps/tell_me_a_story/lib/features/people/add_person_modal.dart` | Mugatu Add Person — pick existing + create new |
| `apps/tell_me_a_story/lib/features/places/place_picker_modal.dart` | Favorites/recents + search + basemap pin |
| `apps/tell_me_a_story/lib/features/places/place_map.dart` | Platform map abstraction (+ `place_map_stub.dart` / `place_map_web.dart` / `place_map_io.dart` as needed) |
| `apps/tell_me_a_story/lib/features/stories/new_story_page.dart` | Minimal `/stories/new` shell hosting people + place only |
| `apps/tell_me_a_story/test/people_api_test.dart` | Fake gateway / parsing tests |
| `apps/tell_me_a_story/test/places_api_test.dart` | Favorites/recents ordering + mark-used |
| `apps/tell_me_a_story/test/add_person_modal_test.dart` | Pick + create chrome (relationship required) |
| `apps/tell_me_a_story/test/place_picker_modal_test.dart` | Favorites/recents sections + Mapbox failure copy |
| `apps/tell_me_a_story/test/new_story_shell_test.dart` | Route shell opens modals; no publish/draft actions |
| `docs/superpowers/plans/2026-09-26-m3-people-places.md` | In-repo copy of this plan |

### Modify

| Path | Change |
|------|--------|
| `apps/tell_me_a_story/lib/core/config/env.dart` | Add `mapboxAccessToken` from `MAPBOX_ACCESS_TOKEN`; soft-validate (empty → map failure path; reject obvious placeholders when non-empty) |
| `apps/tell_me_a_story/lib/core/router/app_router.dart` | Add `AppRoutes.newStory = '/stories/new'`; signed-in route; keep auth redirects |
| `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart` | Smoke-only AppBar action `New story` → `/stories/new`. No invented Stitch chrome. |
| `apps/tell_me_a_story/pubspec.yaml` | Add `http`; add `mapbox_maps_flutter` (iOS) and/or `flutter_map` + tile dependency if chosen for shared basemap; keep versions pinned |
| `apps/tell_me_a_story/test/env_test.dart` | Cover Mapbox define / placeholder rejection |
| `apps/tell_me_a_story/test/router_test.dart` | `/stories/new` reachable when signed-in |
| `README.md` | Document `MAPBOX_ACCESS_TOKEN` dart-define; M3 smoke path via `/stories/new` |

### Explicitly NOT in M3

- Story body / timeframe / photos / Save draft / Publish / `story_people` writes
- New migrations (unless a **blocking** Design Doc mismatch is found — then stop and report CONFLICT)
- Edge Functions, Resend, Storage upload
- Full Memory Album visual redesign (match Mugatu structure; tokens later OK)
- Google Maps SDK

## Data contracts (Design Doc columns — already migrated)

**`people`:** `id`, `family_id`, `name`, `relationship` (required), `email` (optional), `created_by`

**`places`:** `id`, `family_id`, `label`, `address`, `lat`, `lng`, `mapbox_place_id` (optional), `is_favorite` (default false), `last_used_at` (nullable)

**RLS:** member SELECT/INSERT/UPDATE/DELETE on both tables via `is_family_member(family_id)`.

**Recents query (client):**

```dart
.from('places')
.select()
.eq('family_id', familyId)
.not('last_used_at', 'is', null)
.order('last_used_at', ascending: false)
.limit(10);
```

**Favorites query:**

```dart
.from('places')
.select()
.eq('family_id', familyId)
.eq('is_favorite', true)
.order('label');
```

**Mark used on select:**

```dart
.update({'last_used_at': DateTime.now().toUtc().toIso8601String()})
.eq('id', placeId);
```

## UI chrome locks (M3 surfaces)

| Surface | Locked behavior / copy |
|---------|------------------------|
| Add Person — pick | Family people list; select existing |
| Add Person — create | Relationship **required**; email optional (future invite); name required; shared family person only (not deceased-only / public directory) |
| Place picker | Basemap + pin; favorites/recents from `places` |
| Mapbox failure | `Couldn’t load the map. Check your connection and try again.` · Retry: `Try again` |
| Routes | `/stories/new` for capture shell; signed-in home remains `/timeline` |
| EN only | Do not invent extra languages |

**OPEN (Mugatu):** Exact Add Person field/button labels beyond Stitch titles are thin in chrome locks. Use minimal functional EN: `Add person`, `Choose or create`, `Name`, `Relationship`, `Email (optional)`, `Save`, `Cancel`. List this OPEN in the PR if Stitch labels differ.

---

### Task 1: Worktree + plan copy

**Files:**
- Create worktree: `.worktrees/feat-m03-people-places` on `feat/m03-people-places`
- Create: `docs/superpowers/plans/2026-09-26-m3-people-places.md`

**Interfaces:**
- Consumes: latest `origin/main`
- Produces: isolated branch ready for M3 commits

- [ ] **Step 1: Sync main and add worktree**

```bash
cd /Users/jabroni/Projects/mortang-tell-me-a-story
git fetch origin
git checkout main
git pull --ff-only origin main
git worktree add .worktrees/feat-m03-people-places -b feat/m03-people-places origin/main
```

- [ ] **Step 2: Copy approved plan into the worktree docs path**

```bash
cp docs/superpowers/plans/2026-09-26-m3-people-places.md \
  .worktrees/feat-m03-people-places/docs/superpowers/plans/ 2>/dev/null || true
# If file does not exist yet on main, write it in the worktree from the approved session plan.
```

- [ ] **Step 3: Commit plan doc**

```bash
cd .worktrees/feat-m03-people-places
git add docs/superpowers/plans/2026-09-26-m3-people-places.md
git commit -m "$(cat <<'EOF'
docs(m03): add People + places implementation plan

EOF
)"
```

---

### Task 2: Env + Mapbox token wiring

**Files:**
- Modify: `apps/tell_me_a_story/lib/core/config/env.dart`
- Modify: `apps/tell_me_a_story/test/env_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: existing `Env.validate()` for Supabase
- Produces: `Env.mapboxAccessToken`, `Env.hasMapboxToken`

- [ ] **Step 1: Write failing env tests**

```dart
test('mapboxAccessToken reads MAPBOX_ACCESS_TOKEN', () {
  // Use a dedicated test helper or document that this is compile-time;
  // assert placeholder rejection helpers:
  expect(Env.isPlausibleMapboxToken('pk.live_test_token_value_here'), isTrue);
  expect(Env.isPlausibleMapboxToken('...'), isFalse);
  expect(Env.isPlausibleMapboxToken(''), isFalse);
});
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd apps/tell_me_a_story && flutter test test/env_test.dart
```

- [ ] **Step 3: Implement Env additions**

```dart
static const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

static bool get hasMapboxToken => isPlausibleMapboxToken(mapboxAccessToken);

static bool isPlausibleMapboxToken(String value) {
  if (value.isEmpty || value == '...' || value.startsWith('<')) return false;
  return value.length >= 20; // public tokens are long; reject README placeholders
}

// Do NOT throw in validate() for missing Mapbox — unit tests + auth still run.
// Place picker shows locked failure copy when !hasMapboxToken.
```

- [ ] **Step 4: README dart-define line**

Document:

```bash
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=3000 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:57321 \
  --dart-define=SUPABASE_ANON_KEY=<anon> \
  --dart-define=INVITE_APP_ORIGIN=http://127.0.0.1:3000 \
  --dart-define=MAPBOX_ACCESS_TOKEN=<public-token>
```

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/core/config/env.dart \
  apps/tell_me_a_story/test/env_test.dart README.md
git commit -m "$(cat <<'EOF'
feat(m03): wire MAPBOX_ACCESS_TOKEN dart-define

EOF
)"
```

---

### Task 3: People repository

**Files:**
- Create: `apps/tell_me_a_story/lib/data/people_api.dart`
- Create: `apps/tell_me_a_story/test/people_api_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, `family_id`, `auth.uid()`
- Produces:

```dart
class Person {
  const Person({
    required this.id,
    required this.familyId,
    required this.name,
    required this.relationship,
    this.email,
    required this.createdBy,
  });
  final String id;
  final String familyId;
  final String name;
  final String relationship;
  final String? email;
  final String createdBy;
}

abstract class PeopleGateway {
  Future<List<Person>> listPeople(String familyId);
  Future<Person> createPerson({
    required String familyId,
    required String name,
    required String relationship,
    String? email,
  });
}
```

- [ ] **Step 1: Write failing unit tests with a fake in-memory gateway / row parser**

Assert `createPerson` rejects empty `name` or empty `relationship` before network (client-side validation mirroring Design Doc required columns).

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/people_api_test.dart
```

- [ ] **Step 3: Implement `PeopleApi`**

```dart
Future<List<Person>> listPeople(String familyId) async {
  final rows = await _client
      .from('people')
      .select('id, family_id, name, relationship, email, created_by')
      .eq('family_id', familyId)
      .order('name');
  return rows.map(Person.fromJson).toList();
}

Future<Person> createPerson({...}) async {
  final uid = _client.auth.currentUser!.id;
  final row = await _client.from('people').insert({
    'family_id': familyId,
    'name': name.trim(),
    'relationship': relationship.trim(),
    if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    'created_by': uid,
  }).select().single();
  return Person.fromJson(row);
}
```

- [ ] **Step 4: Tests PASS + commit**

```bash
flutter test test/people_api_test.dart
git add apps/tell_me_a_story/lib/data/people_api.dart \
  apps/tell_me_a_story/test/people_api_test.dart
git commit -m "$(cat <<'EOF'
feat(m03): add people PostgREST gateway

EOF
)"
```

---

### Task 4: Places repository (favorites + recents)

**Files:**
- Create: `apps/tell_me_a_story/lib/data/places_api.dart`
- Create: `apps/tell_me_a_story/test/places_api_test.dart`

**Interfaces:**
- Produces:

```dart
class Place {
  const Place({
    required this.id,
    required this.familyId,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    required this.isFavorite,
    this.lastUsedAt,
  });
  // fields...
}

abstract class PlacesGateway {
  Future<List<Place>> listFavorites(String familyId);
  Future<List<Place>> listRecents(String familyId, {int limit = 10});
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  });
  Future<Place> markUsed(String placeId);
  Future<Place> setFavorite({required String placeId, required bool isFavorite});
}
```

- [ ] **Step 1: Failing tests for recents ordering + create payload shape**

- [ ] **Step 2: Implement `PlacesApi` with queries from Data contracts above; on `createPlace` set `last_used_at` to now so new picks appear in recents**

- [ ] **Step 3: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m03): add places gateway with favorites and recents

EOF
)"
```

---

### Task 5: Mapbox search client

**Files:**
- Create: `apps/tell_me_a_story/lib/data/mapbox_search.dart`
- Create: `apps/tell_me_a_story/test/mapbox_search_test.dart`
- Modify: `pubspec.yaml` — add `http`

**Interfaces:**
- Consumes: `Env.mapboxAccessToken`
- Produces:

```dart
class MapboxSearchHit {
  const MapboxSearchHit({
    required this.id,
    required this.placeName,
    required this.lat,
    required this.lng,
  });
  final String id; // mapbox feature id
  final String placeName;
  final double lat;
  final double lng;
}

abstract class MapboxSearchGateway {
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5});
}
```

- [ ] **Step 1: Add dependency**

```bash
cd apps/tell_me_a_story && flutter pub add http
```

- [ ] **Step 2: Failing test parsing a fixture JSON FeatureCollection**

- [ ] **Step 3: Implement GET**

`https://api.mapbox.com/geocoding/v5/mapbox.places/{urlencodedQuery}.json?access_token=...&limit=5`

Throw a typed `MapboxSearchException` on non-200 / missing token so UI can show locked failure copy.

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m03): add Mapbox Geocoding search client

EOF
)"
```

---

### Task 6: Add Person modal (pick + create)

**Files:**
- Create: `apps/tell_me_a_story/lib/features/people/add_person_modal.dart`
- Create: `apps/tell_me_a_story/test/add_person_modal_test.dart`

**Interfaces:**
- Consumes: `PeopleGateway`, `familyId`, optional initial selection
- Produces: `Future<Person?>` from `AddPersonModal.show(...)`

- [ ] **Step 1: Widget test — pick list shows people; create form requires relationship**

```dart
testWidgets('create requires relationship', (tester) async {
  // open create mode, enter name only, tap Save → still open / shows validation
});

testWidgets('pick returns selected person', (tester) async {
  // tap list tile → modal pops with Person
});
```

- [ ] **Step 2: Implement modal with two modes (Choose existing / Create new) matching Stitch inventory titles; Email + Link pattern of tabs is NOT required — use segmented control or secondary button to switch modes as Mugatu “Choose or Create”**

- [ ] **Step 3: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m03): Add Person pick and create modal

EOF
)"
```

---

### Task 7: Place picker modal + PlaceMap

**Files:**
- Create: `apps/tell_me_a_story/lib/features/places/place_picker_modal.dart`
- Create: `apps/tell_me_a_story/lib/features/places/place_map.dart` (+ platform files)
- Create: `apps/tell_me_a_story/test/place_picker_modal_test.dart`
- Modify: `pubspec.yaml` for map dependency choice from Mapbox client approach

**Interfaces:**
- Consumes: `PlacesGateway`, `MapboxSearchGateway`, `familyId`
- Produces: `Future<Place?>` from `PlacePickerModal.show(...)`

- [ ] **Step 1: Widget tests**
  - Renders Favorites and Recents sections from fake gateway
  - When search/map gateway fails or token missing, shows exact strings:
    - `Couldn’t load the map. Check your connection and try again.`
    - `Try again`
  - Selecting a recent calls `markUsed` and pops `Place`

- [ ] **Step 2: Implement `PlaceMap`** showing center pin for `lat`/`lng`; empty/error state delegates to parent failure UI

- [ ] **Step 3: Implement picker** — search field → Mapbox hits → on select create-or-reuse place row → show pin → confirm

**Reuse rule:** If a hit’s `mapbox_place_id` already exists for this `family_id`, `markUsed` that row instead of inserting a duplicate.

- [ ] **Step 4: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m03): Place picker with Mapbox pin, favorites, and recents

EOF
)"
```

---

### Task 8: Minimal `/stories/new` shell + router + timeline entry

**Files:**
- Create: `apps/tell_me_a_story/lib/features/stories/new_story_page.dart`
- Create: `apps/tell_me_a_story/test/new_story_shell_test.dart`
- Modify: `apps/tell_me_a_story/lib/core/router/app_router.dart`
- Modify: `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`
- Modify: `apps/tell_me_a_story/test/router_test.dart`

**Interfaces:**
- Consumes: family id (via `InviteGateway.currentFamilyId` / createFamily bootstrap same as M2 invite), people/places gateways
- Produces: local in-memory selection of `List<Person>` + `Place?` for smoke only (not persisted as a story)

- [ ] **Step 1: Router test — signed-in can open `/stories/new`**

```dart
static const newStory = '/stories/new';
// GoRoute path: '/stories/new' → NewStoryPage
```

- [ ] **Step 2: `NewStoryPage` UI**
  - AppBar title minimal: `New story`
  - People section: chips for selected people + button `Add person` → `AddPersonModal`
  - Place section: if place selected, small `PlaceMap` + label/address; button `Choose place` → `PlacePickerModal`
  - Body note (functional, not marketing): `Capture fields arrive in M4.`
  - **Forbidden:** Save draft / Publish widgets of any kind (including disabled/greyed)

- [ ] **Step 3: Timeline AppBar action** `New story` → `context.push(AppRoutes.newStory)` — **smoke entry only**; do not invent Stitch timeline chrome

- [ ] **Step 4: Widget test shell opens both modals with fakes**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m03): minimal /stories/new shell for people and places

EOF
)"
```

---

### Task 9: Verification + PR

**Files:** none new beyond README tweaks if smoke steps need clarity

- [ ] **Step 1: Automated checks**

```bash
cd /Users/jabroni/Projects/mortang-tell-me-a-story
supabase start   # if not running
supabase test db
cd apps/tell_me_a_story && flutter test
```

Expected: existing RLS/invite/profile tests still PASS; new Flutter tests PASS.

- [ ] **Step 2: Manual local smoke (when Bill provides Mapbox public token)**
  1. `supabase start` + Mailpit magic link → `/timeline`
  2. Ensure family exists (invite flow or create on first action)
  3. Tap `New story` → `/stories/new`
  4. Add person (create + pick)
  5. Choose place — search, pin visible, favorites/recents after re-open
  6. Kill Mapbox token / offline → failure copy + `Try again`

- [ ] **Step 3: Open PR (do not merge)**

```bash
git push -u origin feat/m03-people-places
gh pr create --title "feat(m03): People + places (Mapbox token OPEN)" --body-file /tmp/m03-pr.md
```

PR body must include:
- §15 M3 exit checklist
- First 10 #8
- Host decision: minimal `/stories/new` (full capture M4)
- **OPEN (Bill):** Mapbox account + URL/bundle-restricted public token
- **OPEN (Mugatu):** Add Person exact labels if Stitch differs
- Command output summary for `flutter test` / `supabase test db`
- Explicit non-goals: publish/draft/photos/story_people

---

## Self-review (plan author)

| Spec item | Task |
|-----------|------|
| Shared people list + Add Person pick/create | Tasks 3, 6, 8 |
| Shared places + favorites/recents | Tasks 4, 7, 8 |
| Mapbox client token + picker + pin | Tasks 2, 5, 7 |
| Persist address/lat/lng/`mapbox_place_id` | Task 4 createPlace |
| Locked Mapbox failure copy | Task 7 |
| `/stories/new` route string | Task 8 |
| No Create Family screen / no SMS / no Google Maps | Global constraints |
| No full New Story capture | Task 8 non-goals |
| Local-only exit; Staging MS separate | Global + Task 9 |

**Placeholder scan:** None intentional — Mapbox account remains named OPEN (Bill), same pattern as M2 Resend.

## Execution handoff (after approval)

Plan complete for review. After you approve:

1. **Subagent-Driven (recommended)** — fresh subagent per task + review between tasks  
2. **Inline Execution** — execute in this session with checkpoints  

Which approach?

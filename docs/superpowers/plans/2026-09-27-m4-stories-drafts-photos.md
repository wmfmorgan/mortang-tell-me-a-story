# M4 Stories + Drafts + Photos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` after human approval. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Gate:** Plan-only until human approves. Do not write application code until approval.
>
> **On approval:** Copy this plan to `docs/superpowers/plans/2026-09-27-m4-stories-drafts-photos.md` in the implementation PR (or first commit). Isolated worktree: `.worktrees/feat-m04-stories-drafts-photos` on `feat/m04-stories-drafts-photos`.

**Goal:** Deliver Impl Spec §15 M4 — story capture (timeframe, people, place, text, photos), client compress/upload to private `story-photos`, Save draft / Publish, drafts list, ~20 photo cap — against **local** Supabase. Exit = Bill local smoke.

**Architecture:** Reuse M1 `stories` / `story_people` / `photos` DDL + RLS and M1 `story-photos` bucket (do not alter photos RLS). Reuse M3 people/place pickers already hosted on `/stories/new`. Add PostgREST gateways under `lib/data/`, persist drafts online-only, upload compressed images to `{family_id}/{story_id}/{photo_id}.(jpg|jpeg|png|webp)`, and add Mugatu Drafts list at `/drafts`. No new Edge Functions. No schema invention.

**Tech Stack (locked):** Flutter 3.x, `supabase_flutter` PostgREST + Storage + RLS, `image_picker`, `image` (decode/resize/JPEG), `uuid`. Secrets remain `--dart-define` only (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MAPBOX_ACCESS_TOKEN`).

## Approaches (locked recommendation)

1. **Recommended — extend the M3 capture shell (Approach A).** Keep `/stories/new` as the only capture surface. Create/update `stories` + `story_people` via PostgREST. Resume a draft with `/stories/new?draft=<storyId>` (query, not a new route). Photos upload only after a story row exists. Drafts list is `/drafts`, author-filtered. Timeline stays a stub except smoke-only published titles so Bill can see publish land.
2. **Use `/stories/:storyId` as the editor.** That path is locked as the **published reader** (M5). Using it for drafts collides with the reader.
3. **Autosave on every keystroke, hide Save draft.** Mugatu locks explicit **Save draft** (secondary) and **Publish** (primary). Autosave-only would drop that chrome.

Pick **Approach A** only. Do not ship Approaches 2–3. Do not add an edit route. Do not add “on behalf of” / dictated / deceased capture chrome (US-3 is story content, not extra UI).

## Approval stamps (2026-09-27)

- **Photos RLS:** INSERT stays M1 `member + uploader_id = uid`. Do **not** change M1 photos policies. Author attach on capture = M4; any-member attach on a published story = M5. pgTAP (`story_author_and_photos.sql`) still asserts a **member** can INSERT a photo with `uploader_id = uid`.
- **Publish write:** `publish()` sets **both** `status = 'published'` and `published_at = now()` (column already in Design Doc).
- **Storage allowlist:** path extension and bucket MIME are `.jpg` / `.jpeg` / `.png` / `.webp` only (M1 bucket already lists jpeg/png/webp).
- **Publish UX:** required-field gate + banner `Finish the highlighted fields to publish.` + terracotta `#8B5E4B` ring. **Save draft** is secondary; **Publish story** is primary.
- **Drafts:** author-only `status = draft`; locked empty `No drafts yet. Stories you’re still writing will show up here.`; loading `Loading drafts…`; row actions `Continue writing` / `Discard`.
- **Save draft:** blocked until a decade chip is selected (`timeframe_start` NOT NULL).
- **Capture:** section order Timeframe → People → Place + mini map → Story text → photo strip. No title field. `stories.title` stays null.
- **Timeline smoke:** AppBar `Drafts` → `/drafts`; empty archive `No stories yet. Capture the first one for this family.`
- **Reuse / out:** M1 schema/RLS/bucket; client compress; ~20 cap; no Edge; no schema invention; M5–M7 / SMS / offline / video stay out.

## Global Constraints

- **SoT precedence:** PRD must/must-not → Mugatu screens/copy → SAD names → Design Doc DDL/RLS/Storage → Impl Spec §10 routes/behavior → Client copy & chrome locks for strings.
- **M4 scope only (§15):** Capture; compress/upload to `story-photos`; publish; drafts list; ~20 cap. First 10 **#9 Flutter half** (upload spike).
- **Host decision (locked this plan):** Extend existing `/stories/new` (replace M3 “Capture fields arrive in M4.”). Resume via `?draft=<id>`. Do **not** add `/stories/:storyId/edit`.
- **Host decision (locked):** `timeframe_start` is `date not null` in Design Doc DDL. **Save draft is blocked until a timeframe is chosen.** Do not null the column. Do not invent a sentinel date.
- **Host decision (locked):** Drafts list shows **the current author’s** `status = draft` rows (`author_id = uid`). Family-wide `stories` SELECT stays as Design Doc; “private until published” means **not on the timeline**, not a new RLS policy.
- **Host decision (locked):** Timeline AppBar gets a smoke-only **Drafts** action → `/drafts` (same pattern as M3 **New story**). No Stitch/Memory Album timeline chrome. Body of `/timeline`: locked empty copy when no published stories; otherwise a **smoke-only** title/preview list of `status = published` (no far/mid/near zoom — that is M6).
- **Host decision (locked):** No title field on capture (Mugatu sections: Timeframe, People, Place + mini map, Story text, photo strip). `stories.title` stays null.
- **Host decision (locked):** Timeframe UI = decade chips writing calendar ranges (`1980s` → `1980-01-01`..`1989-12-31`). Chip set **1900s–2020s**. Single-day (`timeframe_end` null) is not a v1 capture control in this milestone.
- **Host decision (locked):** Author photo attach during capture is M4. **Any-member attach to a published story** (US-4 remainder) waits for **M5 reader**. Upload helpers must be reusable. Photos INSERT policy remains M1 `member + uploader_id = uid` — do not add or rewrite photos RLS.
- **Repo map §3:** `features/stories/`, `features/drafts/`. No new Edge Functions. No migrations unless a **blocking** Design Doc mismatch is found — then stop and report CONFLICT.
- **Out of M4:** Story reader, comments, perspectives (M5); timeline zoom + Realtime (M6); search (M7); Resend/cloud staging (Bill / Staging MS); SMS; offline drafts; video; public buckets.
- **Secrets:** Never commit `.env` or service-role keys. Photo bytes go to Storage via the user JWT.
- **Git:** Branch `feat/m04-stories-drafts-photos` from latest `main` in `.worktrees/feat-m04-stories-drafts-photos`. Open PR; do not merge. No `--no-verify`, no force-push.
- **Env rule (Bill 2026-09-26):** Feature MS exit = local smoke. Staging MS is separate and late.

## Preconditions / blockers

| Item | Status at plan time |
|------|---------------------|
| `main` includes M1–M3 (auth, family/invites, people/places, `/stories/new` shell) | Yes — M3 PRs #7+#8 merged; Bill local smoke passed 2026-09-27 |
| `stories` / `story_people` / `photos` tables + RLS | Already in M1 migrations |
| Private `story-photos` bucket + path-prefix policies | Already in M1 (`20260923000005_storage.sql`) |
| Flutter SDK | Present (`3.47.x`) |
| Local Supabase ports `5732x` | Per local-dev memory / README |
| Mapbox public token | Soft; needed only for place pin smoke (already M3) |
| Cloud staging | Deferred to Staging MS — local only |

## Spec match (M4)

| Exit criterion (§15 M4 / US) | M4 agent delivery | Status |
|------------------------------|-------------------|--------|
| Capture timeframe, people, place, text (US-3) | `/stories/new` form + persist | Agent closes |
| Save / resume draft; not on timeline until published (US-11) | Save draft + `/drafts` Continue writing | Agent closes |
| Pictures compress, ~20, private bucket (US-4 author path; First 10 #9) | `image` compress + Storage upload + cap | Agent closes |
| Publish with validation UX | Publish primary; set `status` **and** `published_at`; banner + terracotta highlight | Agent closes |
| Drafts list missing-field chips / Discard | `/drafts` | Agent closes |
| Checks (§14 slice) | `flutter test`; `supabase test db` + new author/photo pgTAP | Agent closes on local |

**PR title/body stance:** `feat(m04): Stories, drafts, and photos` — do not claim Bill smoke closed until Bill runs it.

## Files to touch

### Create

| Path | Responsibility |
|------|----------------|
| `apps/tell_me_a_story/lib/data/stories_api.dart` | `Story` model, publish readiness, `StoriesGateway`; `publish()` writes `status` + `published_at` |
| `apps/tell_me_a_story/lib/data/photos_api.dart` | Path helper `.jpg/.jpeg/.png/.webp`, compress, Storage upload, `photos` rows, 20-cap |
| `apps/tell_me_a_story/lib/features/stories/timeframe_chips.dart` | Decade chip → `timeframe_start`/`timeframe_end` |
| `apps/tell_me_a_story/lib/features/stories/photo_strip.dart` | Add tile + thumbnails + remove + retry |
| `apps/tell_me_a_story/lib/features/drafts/drafts_page.dart` | Drafts list, filters, Continue / Discard |
| `apps/tell_me_a_story/test/stories_api_test.dart` | Parse, draft validation, publish readiness |
| `apps/tell_me_a_story/test/photos_api_test.dart` | Path, cap, compress, STORAGE_FAILED cleanup |
| `apps/tell_me_a_story/test/new_story_capture_test.dart` | Save draft / Publish chrome + blocked banner |
| `apps/tell_me_a_story/test/drafts_page_test.dart` | Empty/loading copy, chips, Continue/Discard |
| `supabase/tests/story_author_and_photos.sql` | §14 author rules + member photo INSERT (`uploader_id = uid`); **no RLS migration** |
| `docs/superpowers/plans/2026-09-27-m4-stories-drafts-photos.md` | In-repo copy of this plan |

### Modify

| Path | Change |
|------|--------|
| `apps/tell_me_a_story/lib/features/stories/new_story_page.dart` | Full capture in Mugatu order (Timeframe → People → Place + map → Story text → photos); persist; no title field; remove M3 placeholder |
| `apps/tell_me_a_story/lib/core/router/app_router.dart` | `AppRoutes.drafts = '/drafts'`; signed-in only; pass `draft` query into `NewStoryPage`; inject `StoriesGateway` / `PhotosGateway` like existing people/places |
| `apps/tell_me_a_story/lib/app.dart` | Thread stories/photos gateways into `createAppRouter` if that is how M3 injects fakes |
| `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart` | AppBar `Drafts` → `/drafts`; smoke published list; locked empty archive copy |
| `apps/tell_me_a_story/test/new_story_shell_test.dart` | Drop “Capture fields arrive in M4.” / “no Save draft” assertions; keep people/place modal tests |
| `apps/tell_me_a_story/test/router_test.dart` | `/drafts` reachable when signed-in; signed-out redirect to magic-link; Timeline `Drafts` action |
| `apps/tell_me_a_story/test/timeline_page_test.dart` | Create if missing: empty archive copy + published preview |
| `apps/tell_me_a_story/pubspec.yaml` | Pin `image_picker`, `image`, `uuid` |
| `README.md` | M4 smoke path |

### Explicitly NOT in M4

- Reader `/stories/:storyId`, comments, perspectives
- Timeline far/mid/near, Realtime `postgres_changes`
- Search, SMS, offline cache, video
- New migrations / Edge Functions
- Weakening `stories` SELECT to author-only
- Google Maps, public Storage URLs

## Data contracts (Design Doc — already migrated)

**`stories`:** `id`, `family_id`, `author_id`, `title` (null in M4), `body` (nullable), `timeframe_start date not null`, `timeframe_end date` nullable, `place_id` nullable, `status` `draft`\|`published` default `draft`, `published_at`. Check: `timeframe_end is null or timeframe_end >= timeframe_start`.

**`story_people`:** PK `(story_id, person_id)` — author INSERT/DELETE.

**`photos`:** `id`, `story_id`, `family_id`, `uploader_id`, `storage_path`, `sort_order`. App enforces max **20**/story.

**Storage:** bucket `story-photos` (private, 50 MiB, `image/jpeg`\|`image/png`\|`image/webp`). Path `{family_id}/{story_id}/{photo_id}.(jpg|jpeg|png|webp)`.

**RLS (do not change — no M4 migration):** stories SELECT member; INSERT member + `author_id = uid`; UPDATE/DELETE author + member. Photos INSERT **member + `uploader_id = uid`** (M1); UPDATE/DELETE uploader or story author + member.

## UI chrome locks (M4 surfaces)

| Surface | Locked behavior / copy |
|---------|------------------------|
| New Story actions | Save draft (secondary), Publish story (primary). AppBar title `New story`. |
| Publish blocked | Banner `Finish the highlighted fields to publish.` Highlight missing fields (terracotta `#8B5E4B` focus ring). Stay on form. Save draft still available (once timeframe exists). |
| Publish required | (1) non-empty body (2) timeframe (3) ≥1 person (4) place with pin. Photos optional. |
| Almost-ready chip | `Ready to publish` when 1–4 complete (photos missing OK). |
| Drafts empty | `No drafts yet. Stories you’re still writing will show up here.` |
| Drafts loading | `Loading drafts…` |
| Drafts row | Status chips for missing fields; `Continue writing`; `Discard` |
| Timeline empty | `No stories yet. Capture the first one for this family.` |
| Mapbox (existing) | `Couldn’t load the map. Check your connection and try again.` / `Try again` |
| Photo retry | Button `Try again`. Inferred EN (OPEN Mugatu): `Couldn’t upload the photo. Check your connection and try again.` |
| Draft saved toast | Inferred EN (OPEN Mugatu): `Draft saved` |
| Routes | `/stories/new`, `/drafts`; signed-in home `/timeline` |
| EN only | Do not invent extra languages |

---

### Task 1: Worktree + plan copy

**Files:**
- Create worktree: `.worktrees/feat-m04-stories-drafts-photos` on `feat/m04-stories-drafts-photos`
- Create: `docs/superpowers/plans/2026-09-27-m4-stories-drafts-photos.md`

**Interfaces:**
- Consumes: latest `origin/main`
- Produces: isolated branch ready for M4 commits

- [ ] **Step 1: Sync main and add worktree**

```bash
cd /Users/jabroni/Projects/mortang-tell-me-a-story
git fetch origin
git checkout main
git pull --ff-only origin main
git worktree add .worktrees/feat-m04-stories-drafts-photos -b feat/m04-stories-drafts-photos origin/main
```

- [ ] **Step 2: Copy approved plan into the worktree docs path**

Write `docs/superpowers/plans/2026-09-27-m4-stories-drafts-photos.md` from the approved session plan.

- [ ] **Step 3: Commit plan doc**

```bash
cd .worktrees/feat-m04-stories-drafts-photos
git add docs/superpowers/plans/2026-09-27-m4-stories-drafts-photos.md
git commit -m "$(cat <<'EOF'
docs(m04): add Stories + drafts + photos implementation plan

EOF
)"
```

---

### Task 2: Stories repository

**Files:**
- Create: `apps/tell_me_a_story/lib/data/stories_api.dart`
- Create: `apps/tell_me_a_story/test/stories_api_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, `Person` / `Place` ids, `auth.uid()`
- Produces:

```dart
enum StoryStatus { draft, published }

class Story {
  const Story({
    required this.id,
    required this.familyId,
    required this.authorId,
    this.title,
    this.body,
    required this.timeframeStart,
    this.timeframeEnd,
    this.placeId,
    required this.status,
    this.publishedAt,
    this.personIds = const [],
    this.photoCount = 0,
  });
  final String id;
  final String familyId;
  final String authorId;
  final String? title;
  final String? body;
  final DateTime timeframeStart; // date only
  final DateTime? timeframeEnd;
  final String? placeId;
  final StoryStatus status;
  final DateTime? publishedAt;
  final List<String> personIds;
  final int photoCount;
}

class PublishReadiness {
  const PublishReadiness({
    required this.hasBody,
    required this.hasTimeframe,
    required this.hasPerson,
    required this.hasPlace,
  });
  final bool hasBody;
  final bool hasTimeframe;
  final bool hasPerson;
  final bool hasPlace;
  bool get canPublish =>
      hasBody && hasTimeframe && hasPerson && hasPlace;
}

PublishReadiness publishReadiness({
  required String? body,
  required DateTime? timeframeStart,
  required Iterable<String> personIds,
  required String? placeId,
}) {
  return PublishReadiness(
    hasBody: (body ?? '').trim().isNotEmpty,
    hasTimeframe: timeframeStart != null,
    hasPerson: personIds.isNotEmpty,
    hasPlace: placeId != null && placeId.isNotEmpty,
  );
}

void ensureValidDraftSave({required DateTime? timeframeStart}) {
  if (timeframeStart == null) {
    throw ArgumentError.value(
      timeframeStart,
      'timeframeStart',
      'must be set before save draft',
    );
  }
}

abstract class StoriesGateway {
  Future<Story> createDraft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  });
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String>? personIds,
  });
  Future<Story> publish(String storyId);
  Future<Story> getStory(String storyId);
  Future<List<Story>> listMyDrafts(String familyId);
  Future<List<Story>> listPublished(String familyId);
  Future<void> discard(String storyId);
}
```

- [ ] **Step 1: Write failing unit tests**

```dart
test('ensureValidDraftSave rejects missing timeframe', () {
  expect(
    () => ensureValidDraftSave(timeframeStart: null),
    throwsArgumentError,
  );
});

test('publishReadiness requires body, timeframe, person, place', () {
  final r = publishReadiness(
    body: '  ',
    timeframeStart: DateTime(1980, 1, 1),
    personIds: const [],
    placeId: null,
  );
  expect(r.canPublish, isFalse);
  expect(r.hasBody, isFalse);
  expect(r.hasTimeframe, isTrue);
  expect(r.hasPerson, isFalse);
  expect(r.hasPlace, isFalse);
});

test('Story.fromJson maps draft status and nested person ids', () {
  final s = Story.fromJson({
    'id': 's1',
    'family_id': 'f1',
    'author_id': 'u1',
    'title': null,
    'body': 'Jam',
    'timeframe_start': '1980-01-01',
    'timeframe_end': '1989-12-31',
    'place_id': 'p1',
    'status': 'draft',
    'published_at': null,
    'story_people': [
      {'person_id': 'a'},
      {'person_id': 'b'},
    ],
    'photos': [
      {'id': 'ph1'},
    ],
  });
  expect(s.status, StoryStatus.draft);
  expect(s.personIds, ['a', 'b']);
  expect(s.photoCount, 1);
  expect(s.timeframeStart, DateTime(1980, 1, 1));
});
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd apps/tell_me_a_story && flutter test test/stories_api_test.dart
```

Expected: FAIL (library missing).

- [ ] **Step 3: Implement `StoriesApi`**

Create draft:

```dart
Future<Story> createDraft({...}) async {
  ensureValidDraftSave(timeframeStart: timeframeStart);
  final uid = _client.auth.currentUser!.id;
  final row = await _client.from('stories').insert({
    'family_id': familyId,
    'author_id': uid,
    'body': body?.trim(),
    'timeframe_start': _date(timeframeStart),
    'timeframe_end': timeframeEnd == null ? null : _date(timeframeEnd),
    'place_id': placeId,
    'status': 'draft',
  }).select(_storySelect).single();
  final story = Story.fromJson(row);
  await _replacePeople(story.id, personIds);
  return getStory(story.id);
}
```

`_storySelect` = `'id, family_id, author_id, title, body, timeframe_start, timeframe_end, place_id, status, published_at, story_people(person_id), photos(id)'`.

`listMyDrafts`: `.eq('family_id', familyId).eq('status', 'draft').eq('author_id', uid).order('timeframe_start')`.

`listPublished`: `.eq('family_id', familyId).eq('status', 'published').order('timeframe_start')`.

`publish`: if `!publishReadiness(...).canPublish` throw `ArgumentError` with message code `VALIDATION`; else update **both** `{status: 'published', published_at: <utc now iso>}`. Never publish with `published_at` null.

`_replacePeople`: delete existing `story_people` for `storyId`, then insert `{story_id, person_id}` for each id.

`discard`: `from('stories').delete().eq('id', storyId)` (cascades `story_people` + `photos` rows). Caller in Task 3 also removes Storage objects.

Date helper writes `YYYY-MM-DD` only (column is `date`).

- [ ] **Step 4: Tests PASS + commit**

```bash
git add apps/tell_me_a_story/lib/data/stories_api.dart \
  apps/tell_me_a_story/test/stories_api_test.dart
git commit -m "$(cat <<'EOF'
feat(m04): add stories PostgREST gateway and publish readiness

EOF
)"
```

---

### Task 3: Photos path, compress, upload

**Files:**
- Create: `apps/tell_me_a_story/lib/data/photos_api.dart`
- Create: `apps/tell_me_a_story/test/photos_api_test.dart`
- Modify: `apps/tell_me_a_story/pubspec.yaml` — add pinned `image`, `uuid` (picker is Task 6)

**Interfaces:**
- Consumes: `SupabaseClient`, story id + family id, raw image bytes
- Produces:

```dart
const maxPhotosPerStory = 20;
const storyPhotosBucket = 'story-photos';

String storyPhotoStoragePath({
  required String familyId,
  required String storyId,
  required String photoId,
  required String ext,
}) {
  final e = ext.toLowerCase();
  if (e != 'jpg' && e != 'jpeg' && e != 'png' && e != 'webp') {
    throw ArgumentError.value(ext, 'ext');
  }
  return '$familyId/$storyId/$photoId.$e';
}

class CompressedPhoto {
  const CompressedPhoto({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });
  final Uint8List bytes;
  final String mimeType; // image/jpeg
  final String extension; // jpg
}

CompressedPhoto compressStoryPhoto(
  Uint8List bytes, {
  int maxEdge = 1920,
  int quality = 80,
});

abstract class PhotosGateway {
  Future<List<Photo>> listPhotos(String storyId);
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  });
  Future<void> deletePhoto(Photo photo);
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  });
}
```

- [ ] **Step 1: Write failing tests**

```dart
test('storyPhotoStoragePath uses family/story/photo.ext', () {
  expect(
    storyPhotoStoragePath(
      familyId: 'f',
      storyId: 's',
      photoId: 'p',
      ext: 'JPG',
    ),
    'f/s/p.jpg',
  );
});

test('storyPhotoStoragePath rejects gif', () {
  expect(
    () => storyPhotoStoragePath(
      familyId: 'f',
      storyId: 's',
      photoId: 'p',
      ext: 'gif',
    ),
    throwsArgumentError,
  );
});

test('compressStoryPhoto emits jpeg under max edge', () {
  final src = _solidPng(2000, 1000); // test helper
  final out = compressStoryPhoto(src);
  expect(out.mimeType, 'image/jpeg');
  expect(out.extension, 'jpg');
  final decoded = img.decodeJpg(out.bytes)!;
  expect(decoded.width <= 1920, isTrue);
  expect(decoded.height <= 1920, isTrue);
});

test('uploadPhoto refuses a 21st image', () async {
  final api = PhotosApi(client: fake, maxCountLoader: () async => 20);
  expect(
    () => api.uploadPhoto(
      familyId: 'f',
      storyId: 's',
      bytes: Uint8List(0),
      sortOrder: 20,
    ),
    throwsA(isA<StateError>()),
  );
});
```

For the cap test, put the count check in a package-visible function:

```dart
void ensurePhotoCap(int currentCount) {
  if (currentCount >= maxPhotosPerStory) {
    throw StateError('PHOTO_CAP');
  }
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/photos_api_test.dart
```

- [ ] **Step 3: Implement compress + upload**

Compress with `package:image/image.dart`: decode → if longest edge > 1920 scale → `encodeJpg(quality: 80)`. Always store `.jpg` / `image/jpeg` (bucket allows jpeg).

Upload sequence (STORAGE_FAILED — no orphan `photos` row):

1. `ensurePhotoCap(await countPhotos(storyId))`
2. `photoId = Uuid().v4()`
3. `compressed = compressStoryPhoto(bytes)`
4. `path = storyPhotoStoragePath(..., ext: compressed.extension)`
5. `storage.from(storyPhotosBucket).uploadBinary(path, compressed.bytes, fileOptions: FileOptions(contentType: compressed.mimeType, upsert: false))`
6. On storage throw: map to a small `StorageFailedException(code: 'STORAGE_FAILED')`; **do not** insert `photos`
7. Insert `photos` `{id: photoId, story_id, family_id, uploader_id: uid, storage_path: path, sort_order}`
8. If insert throws: `storage.from(bucket).remove([path])` then rethrow

`deleteAllForStory`: `storage.from(bucket).list('$familyId/$storyId')` then `remove`; used by Discard.

- [ ] **Step 4: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m04): compress and upload story photos to private storage

EOF
)"
```

---

### Task 4: pgTAP author + photo policies

**Files:**
- Create: `supabase/tests/story_author_and_photos.sql`

**Interfaces:**
- Consumes: existing RLS policies (no migration)
- Produces: §14 items 2 (author rules) + photo INSERT as member

- [ ] **Step 1: Write the SQL test** (transaction + ROLLBACK, same harness as `rls_two_family_isolation.sql`)

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- seed user_a family_a story_a; user_b member of family_a (accept via insert membership as definer/service)
-- 1. user_b SELECT story_a succeeds (member)
-- 2. user_b UPDATE story_a body returns 0 rows (non-author)
-- 3. user_b INSERT photos on story_a succeeds (member + uploader_id = b)
-- 4. user_b UPDATE stories.family_id to family_b returns 0 (WITH CHECK membership)

select * from finish();
rollback;
```

Use two users in **one** family for author vs member photo insert. Create family as A; insert B’s membership with `set role none` / table owner (the isolation test already inserts `auth.users`; for membership insert, use `reset role` then insert as postgres, matching how Edge would). If inserting membership as postgres is awkward, have A create family, then run a `security definer` test helper **only if already present**. Prefer: A creates family; B creates own family; **do not** weaken policies. For “member can INSERT photo”, add B to A’s family via:

```sql
reset role;
insert into public.memberships (family_id, user_id, role)
select family_a, user_b, 'member' from test_ctx;
```

That is test-harness only (postgres), same spirit as seeding.

- [ ] **Step 2: Run**

```bash
supabase test db
```

Expected: existing tests still PASS; new file PASS.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
test(m04): pgTAP author-only story update and member photo insert

EOF
)"
```

---

### Task 5: Timeframe chips + capture persist chrome

**Files:**
- Create: `apps/tell_me_a_story/lib/features/stories/timeframe_chips.dart`
- Create: `apps/tell_me_a_story/test/new_story_capture_test.dart`
- Modify: `apps/tell_me_a_story/lib/features/stories/new_story_page.dart`
- Modify: `apps/tell_me_a_story/test/new_story_shell_test.dart`

**Interfaces:**
- Consumes: `StoriesGateway`, existing people/place selection
- Produces: Save draft / Publish on `/stories/new`; decade range helper

```dart
class DecadeRange {
  const DecadeRange(this.startYear);
  final int startYear; // 1980
  DateTime get start => DateTime(startYear, 1, 1);
  DateTime get end => DateTime(startYear + 9, 12, 31);
  String get label => '${startYear}s';
}

const decadeChips = [
  DecadeRange(1900), DecadeRange(1910), /* … */ DecadeRange(2020),
];
```

- [ ] **Step 1: Failing widget tests**

```dart
testWidgets('shows Save draft and Publish', (tester) async {
  await tester.pumpWidget(_captureShell());
  await tester.pumpAndSettle();
  expect(find.text('Save draft'), findsOneWidget);
  expect(find.text('Publish story'), findsOneWidget);
  expect(find.text('Capture fields arrive in M4.'), findsNothing);
});

testWidgets('Save draft disabled until a decade is selected', (tester) async {
  await tester.pumpWidget(_captureShell());
  await tester.pumpAndSettle();
  final save = tester.widget<TextButton>(
    find.widgetWithText(TextButton, 'Save draft'),
  );
  expect(save.onPressed, isNull);
});

testWidgets('blocked Publish shows banner and stays on form', (tester) async {
  await tester.pumpWidget(_captureShell());
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, '1980s'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
  await tester.pumpAndSettle();
  expect(find.text('Finish the highlighted fields to publish.'), findsOneWidget);
  expect(find.text('New story'), findsOneWidget);
});

testWidgets('Save draft with timeframe calls createDraft', (tester) async {
  final stories = _FakeStoriesApi();
  await tester.pumpWidget(_captureShell(stories: stories));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, '1980s'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
  await tester.pumpAndSettle();
  expect(stories.createDraftCalls, 1);
  expect(find.text('Draft saved'), findsOneWidget);
});
```

Inject `StoriesGateway` on `NewStoryPage` the same way people/places are injected.

- [ ] **Step 2: Run — expect FAIL** (`Save draft` missing)

```bash
flutter test test/new_story_capture_test.dart test/new_story_shell_test.dart
```

- [ ] **Step 3: Implement capture UI on `NewStoryPage`**

Layout order (Mugatu): Timeframe chips → People (existing) → Place + mini map (existing) → Story `TextField` (multiline, label `Story`) → photo strip placeholder (empty until Task 6) → AppBar/actions **Save draft** + **Publish story**.

Behavior:
- Selecting a decade sets `_timeframeStart/_timeframeEnd`.
- Save draft: `createDraft` or `updateDraft` if `_storyId != null`; SnackBar `Draft saved`.
- Publish: compute `publishReadiness`; if `!canPublish` set `_showPublishBanner = true` and wrap missing sections with a terracotta (`Color(0xFF8B5E4B)`) border; **do not** navigate. If ready: save then `publish(id)` then `context.go(AppRoutes.timeline)`.
- If query `draft` is present, `getStory` and hydrate people/place/body/timeframe (people via `listPeople` filtered by ids).
- When `canPublish`, show chip `Ready to publish`.

Update `new_story_shell_test.dart`: remove assertions that Save draft / Publish are absent and that the M3 placeholder is present. Keep modal tests.

- [ ] **Step 4: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m04): capture timeframe, body, save draft, and publish validation

EOF
)"
```

---

### Task 6: Photo strip on capture

**Files:**
- Create: `apps/tell_me_a_story/lib/features/stories/photo_strip.dart`
- Modify: `apps/tell_me_a_story/lib/features/stories/new_story_page.dart`
- Modify: `apps/tell_me_a_story/test/new_story_capture_test.dart`
- Modify: `apps/tell_me_a_story/pubspec.yaml` — pin `image_picker`

**Interfaces:**
- Consumes: `PhotosGateway`, `StoriesGateway` (auto-save draft before first upload)
- Produces: add / remove / retry on the strip

```dart
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
    required this.uploadFailed,
    required this.canAdd,
  });
}
```

- [ ] **Step 1: Failing tests**

```dart
testWidgets('Add photo without timeframe does not pick', (tester) async {
  await tester.pumpWidget(_captureShell());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('photo-add')));
  await tester.pumpAndSettle();
  expect(find.text('Finish the highlighted fields to publish.'), findsNothing);
  // Timeframe section highlighted or Save-draft requirement: add is no-op
  expect(find.byKey(const Key('photo-thumb')), findsNothing);
});

testWidgets('Add photo after decade uploads via gateway', (tester) async {
  final photos = _FakePhotosApi();
  final picker = _FakePicker(bytes: _tinyJpeg);
  await tester.pumpWidget(_captureShell(photos: photos, picker: picker));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, '1980s'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('photo-add')));
  await tester.pumpAndSettle();
  expect(photos.uploadCalls, 1);
  expect(find.byKey(const Key('photo-thumb')), findsOneWidget);
});

testWidgets('upload failure shows retry copy', (tester) async {
  final photos = _FakePhotosApi(failUpload: true);
  await tester.pumpWidget(_captureShell(photos: photos, picker: _FakePicker()));
  // select decade, tap add
  expect(
    find.text('Couldn’t upload the photo. Check your connection and try again.'),
    findsOneWidget,
  );
  expect(find.text('Try again'), findsOneWidget);
});
```

Inject a `Future<Uint8List?> Function()` picker on `NewStoryPage` so widget tests never open the real gallery.

- [ ] **Step 2: Implement**

On add:
1. If no timeframe, treat like blocked publish for timeframe only (terracotta on Timeframe). Do not open picker.
2. Else `createDraft`/`updateDraft` so `_storyId` exists.
3. `picker()` → if null, return.
4. `photos.uploadPhoto(...)`. On `StorageFailedException`, set `_photoError = true`.
5. If `photos.length >= 20`, hide add tile.

On remove: `deletePhoto` then drop from local list (author is uploader).

Production picker: `ImagePicker().pickImage(source: ImageSource.gallery)` then `readAsBytes()`. iOS + web.

- [ ] **Step 3: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m04): photo strip with compress-upload and retry

EOF
)"
```

---

### Task 7: Drafts list + `/drafts` route

**Files:**
- Create: `apps/tell_me_a_story/lib/features/drafts/drafts_page.dart`
- Create: `apps/tell_me_a_story/test/drafts_page_test.dart`
- Modify: `apps/tell_me_a_story/lib/core/router/app_router.dart`
- Modify: `apps/tell_me_a_story/test/router_test.dart`

**Interfaces:**
- Consumes: `StoriesGateway.listMyDrafts`, `discard`, `PhotosGateway.deleteAllForStory`
- Produces: `/drafts` signed-in route

- [ ] **Step 1: Failing tests**

```dart
testWidgets('empty drafts copy', (tester) async {
  await tester.pumpWidget(_drafts(stories: _FakeStoriesApi(drafts: [])));
  await tester.pumpAndSettle();
  expect(
    find.text('No drafts yet. Stories you’re still writing will show up here.'),
    findsOneWidget,
  );
});

testWidgets('loading copy', (tester) async {
  await tester.pumpWidget(_drafts(stories: _SlowStoriesApi()));
  await tester.pump(); // before future completes
  expect(find.text('Loading drafts…'), findsOneWidget);
});

testWidgets('missing-field chips and Ready to publish', (tester) async {
  await tester.pumpWidget(_drafts(stories: _FakeStoriesApi(drafts: [
    _draft(body: null, personIds: [], placeId: null), // missing text/people/place
    _draft(body: 'Jam', personIds: ['p'], placeId: 'pl', photoCount: 0),
  ])));
  await tester.pumpAndSettle();
  expect(find.text('Ready to publish'), findsOneWidget);
});

testWidgets('Continue writing goes to /stories/new?draft=id', (tester) async {
  // Use a small GoRouter harness
});

testWidgets('Discard calls discard and removes the row', (tester) async {
  final api = _FakeStoriesApi(drafts: [_draft(id: 's1')]);
  await tester.pumpWidget(_drafts(stories: api));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Discard'));
  await tester.pumpAndSettle();
  expect(api.discarded, ['s1']);
});
```

Router:

```dart
static const drafts = '/drafts';
// signed-in only; signed-out → `/`
```

- [ ] **Step 2: Implement `DraftsPage`**

AppBar title `Drafts`. Filter chips (functional EN, list OPEN if Stitch differs): `All`, `Missing text`, `Missing people`, `Missing place`, `Missing photos`, `Ready to publish`.

Row: timeframe label (`1980s` if range is a full decade, else `YYYY-MM-DD`) + body preview or `Untitled`; missing chips; `Continue writing` → `context.push('${AppRoutes.newStory}?draft=${story.id}')`; `Discard` → `deleteAllForStory` then `discard(id)` then refresh.

- [ ] **Step 3: Tests PASS + commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m04): drafts list with missing-field chips and discard

EOF
)"
```

---

### Task 8: Timeline smoke list + Drafts entry

**Files:**
- Modify: `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`
- Modify: `apps/tell_me_a_story/test/router_test.dart`
- Add widget coverage in existing timeline tests or `test/timeline_page_test.dart` if none exists

**Interfaces:**
- Consumes: `StoriesGateway.listPublished`
- Produces: smoke AppBar `Drafts`; published previews; locked empty copy

- [ ] **Step 1: Tests**

```dart
testWidgets('Timeline AppBar Drafts pushes /drafts', (tester) async { ... });

testWidgets('empty published list shows locked empty copy', (tester) async {
  expect(
    find.text('No stories yet. Capture the first one for this family.'),
    findsOneWidget,
  );
  expect(find.text('Timeline'), findsWidgets); // title still present
});

testWidgets('published story preview appears after listPublished', (tester) async {
  expect(find.textContaining('Jam'), findsOneWidget);
});
```

- [ ] **Step 2: Implement**

AppBar actions order: `New story` | `Drafts` | `+ Invite`.

Body: if loading published, small progress; if empty, centered locked empty copy; else `ListView` of published rows (timeframe label + body preview). **No** zoom controls, **no** Memory Album redesign. Row tap is a no-op in M4 (reader is M5) — do not invent `/stories/:id` navigation.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(m04): timeline drafts entry and published smoke list

EOF
)"
```

---

### Task 9: README + verification + PR

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document M4 smoke**

After M3 people/place steps:

1. Pick a decade chip
2. Enter story text
3. **Save draft** → toast `Draft saved`
4. Open **Drafts** → row with missing-field chips → **Continue writing** resumes
5. Add a photo (≤20); kill network / fail Storage → photo retry copy + `Try again`
6. Fill people + place + text → **Publish story**
7. Land on `/timeline`; draft gone from Drafts; preview listed
8. Blocked Publish (missing fields) stays on form with `Finish the highlighted fields to publish.`

- [ ] **Step 2: Automated checks**

```bash
supabase test db
cd apps/tell_me_a_story && flutter test
```

Expected: existing RLS/invite/profile tests PASS; new pgTAP PASS; Flutter tests PASS.

- [ ] **Step 3: Open PR (do not merge)**

```bash
git push -u origin feat/m04-stories-drafts-photos
gh pr create --title "feat(m04): Stories, drafts, and photos" --body-file /tmp/m04-pr.md
```

PR body must include:
- §15 M4 exit checklist + First 10 #9 Flutter upload
- Host decisions: timeframe required to save; author-only drafts list; `?draft=` resume; smoke published list; member-attach-on-published deferred to M5
- **OPEN (Mugatu):** `Draft saved` toast; photo failure sentence (retry label locked as `Try again`); drafts filter chip labels
- Command output for `flutter test` / `supabase test db`
- Explicit non-goals: reader/comments/perspectives, timeline zoom/Realtime, search

---

## Self-review (plan author)

| Spec item | Task |
|-----------|------|
| Capture timeframe/people/place/text (US-3) | 2, 5 |
| Decade chips → date range (Design Doc) | 5 |
| Save/resume draft; not on timeline (US-11) | 2, 5, 7, 8 |
| Drafts empty/loading copy + missing chips | 7 |
| Publish validation banner + required 1–4 | 5 |
| Photos compress, ~20, private path (US-4 author / #9) | 3, 6 |
| STORAGE_FAILED no orphan DB row + `Try again` | 3, 6 |
| §14 author UPDATE + member photo INSERT | 4 |
| `/stories/new` + `/drafts` routes | 5, 7 |
| Online-only (no Hive/SQLite drafts) | Global |
| No reader / zoom / search / SMS | Global |

**Placeholder scan:** Named OPENs only — Mugatu strings for draft toast, photo error sentence, drafts filter labels. Mapbox token remains prior OPEN (M3). Resend remains Bill OPEN (not M4).

**Type consistency:** `StoriesGateway.createDraft/updateDraft/publish/listMyDrafts/listPublished/discard`; `PhotosGateway.uploadPhoto/deletePhoto/deleteAllForStory`; `PublishReadiness.canPublish`; `maxPhotosPerStory = 20`; `storyPhotoStoragePath`; route `AppRoutes.drafts`.

## Execution handoff (after approval)

Plan complete for review. After you approve:

1. **Subagent-Driven (recommended)** — fresh subagent per task + review between tasks
2. **Inline Execution** — execute in this session with checkpoints

Which approach?

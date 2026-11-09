# M5 Reader — Comments + Perspectives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` after human approval. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Gate:** Plan-only until human approves. Do not write application code until approval.
>
> **On approval:** Copy this plan to `docs/superpowers/plans/2026-09-27-m5-reader-comments-perspectives.md` in the first commit. Isolated worktree: `.worktrees/feat-m05-reader-comments-perspectives` on `feat/m05-reader-comments-perspectives` from **latest `main`**.

**Goal:** Deliver Impl Spec §15 M5 — published story **reader** at `/stories/:storyId`, with **Comments** and **Perspectives** as separate sections, nested `profiles.display_name` via co-member SELECT, and any-member photo attach on a published story. Exit = **Bill local smoke**. Open PR; do not merge.

**Architecture:** Reuse M1 `comments` / `perspectives` / `photos` DDL + RLS (photos INSERT already allows any member with `uploader_id = uid`). One new migration: replace own-only `profiles` SELECT with own **or co-member**. Flutter adds `CommentsGateway` + `PerspectivesGateway` (PostgREST nested `profiles!author_id(display_name)`), a published-only `StoryReaderPage`, and an Add Perspective overlay. Timeline published cards navigate to the reader. Reuse M4 `PhotosGateway` compress/upload/cap/download. No Edge Functions. No Realtime (M6). No Search (M7). No denormalized author-name columns.

**Tech Stack:** Flutter 3.x, `supabase_flutter` PostgREST + Storage + RLS, existing `image_picker` / `image` / `uuid`, Memory Album `albumTheme()` from M4.5. Secrets remain `--dart-define` only.

## Approaches (locked recommendation)

1. **Recommended — published reader + PostgREST nested profiles (Approach A).** New routes `/stories/:storyId` (reader) and `/stories/:storyId/perspective` (overlay). Load published story + people + place + photos + comments + perspectives. Author names from nested `profiles.display_name` (fallback `Member`). Comment composer inline; perspective is a full-telling overlay. Any member can attach photos via existing `PhotosGateway.uploadPhoto`. One profiles RLS migration only.
2. **Denormalize `author_display_name` onto comments/perspectives.** Bill 2026-09-27 lock: nested `profiles.display_name` via co-member SELECT. **Forbidden.**
3. **Treat `/stories/:storyId` as an editor and put comments in a sheet.** Path is locked as the **published reader**. Capture stays `/stories/new`. Comments and Perspectives are **separate sections on the reader**, not one thread.

Pick **Approach A** only.

## Sources (do not invent past these)

- Impl Spec §15 M5 + §10 Reader / Add Perspective / routes: https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Design Doc DDL/RLS (profiles co-member SELECT; comments/perspectives author-only write): https://app.notion.com/p/3e0c4bcef23881c0ba43db61e6195ec7
- Chrome/copy locks (routes; no reader empty strings — Stitch labels fill the gap): https://app.notion.com/p/3e0c4bcef23881e59430d4f904bc59a3
- Stitch project `12192342757314667328`
  - Story Reader `screens/3ca683beb0144a658fd5074b665fe6af`
  - Add Perspective Modal `screens/8964211b6cd145dd99e4ddaa3e694728`
- M4 photos helpers already on main (`PhotosGateway`, `downloadBytes`, ~20 cap, private `story-photos`)
- M4.5 `albumTheme()` already on `MaterialApp.router`

## Approval stamps (proposed — confirm)

- **Profiles RLS:** Drop `profiles_select_own`. Add SELECT: `id = auth.uid()` **OR** shares ≥1 family via `memberships`. UPDATE/DELETE stay own-id. INSERT stays trigger-only. **No** denormalized author names.
- **Reader route:** `/stories/:storyId` is **published-only**. Draft or missing → not-found chrome (`NOT_FOUND`). Do not open capture. Do not leak “this is a draft.”
- **Timeline:** published card tap → `context.push('/stories/$id')`. Keep AppBar `New story | Drafts | + Invite`.
- **Headline:** `stories.title` stays null (M4). Reader headline = first non-empty line of `body`, else `Untitled` (same as timeline preview). Do not add a title field.
- **Comments vs Perspectives:** separate tables, separate sections. Comments = short note + **Post**. Perspectives = full alternate telling overlay. No threading (`parent_id` does not exist). No voice/audio.
- **Display name:** nested `profiles.display_name`; null/empty → `Member` (§10).
- **Photos:** any member may attach on the **published** reader (US-4 remainder). Reuse M4 upload path. Photos INSERT policy **unchanged** (`member + uploader_id = uid`). Cap ~20. Author/uploader may delete per existing RLS.
- **Author edit of published core (US-5 UI / Stitch “Edit story”):** **OUT of M5.** RLS already blocks non-author UPDATE. Edit-story chrome waits for a later slice.
- **Perspective schema:** `body` only. Stitch “Perspective title (optional)” is **not** a column — do not add it.
- **Skin:** inherit `albumTheme()`. Match Stitch **section structure** (story, people, place, photos, Perspectives, Comments). Do not ship keepsake-demo chrome (Archive ID, Volume IV, 4 min read, voice cassette, Print, Export PDF, Archive Settings, photo captions/types).
- **Realtime / Search / zoom / Invite polish:** OUT.
- **Git:** branch `feat/m05-reader-comments-perspectives` from latest `main`. Open PR; do not merge.

## Stitch labels to use (chrome locks are silent here)

| Surface | Copy |
|---------|------|
| Back | `Timeline` |
| Photos section | `Add photos` |
| Perspectives header | `Perspectives` |
| Perspectives CTA | `+ Add your perspective` |
| Comments header | `Comments` |
| Comments CTA | `+ Add comment` |
| Comment placeholder | `Share a short memory or note...` |
| Comment submit | `Post` |
| Perspective overlay title | `Add your perspective` |
| Perspective helper | `Tell this story in your own words — a full telling, not a quick reaction.` |
| Perspective body label | `Your story` |
| Perspective body placeholder | `What do you remember? Who was there, what was said…` |
| Perspective primary | `Publish perspective` |
| Perspective secondary | `Cancel` |
| Attribution fallback | `Member` |

**OPEN Mugatu (do not invent extras):** empty-list sentences, comment/perspective save failure toast, not-found sentence. Use existing error patterns: SnackBar + `Try again` where a retry exists; generic not-found body if Stitch has none.

## Global Constraints

- **SoT precedence:** PRD must/must-not → Mugatu screens/copy → SAD names → Design Doc DDL/RLS/Storage → Impl Spec §10 routes/behavior → Client copy locks for strings.
- **M5 scope only (§15):** Reader; comments + perspectives separate; nested `profiles.display_name` via co-member SELECT; any-member attach on published.
- **Repo map §3:** reader in `features/stories/`; Add Perspective in `features/perspectives/`; comments in `features/comments/`.
- **No new Edge Functions.** One migration for profiles SELECT only. Stop and report CONFLICT if any other schema gap appears.
- **Online-only.** No Hive/SQLite.
- **Secrets:** Never commit `.env` or service-role keys.
- **Env rule (Bill 2026-09-26):** Feature MS exit = local smoke. Staging MS is separate and late.

## Preconditions

| Item | Status |
|------|--------|
| `main` tip includes M1–M4.5 (PRs #1–#13) | Yes — `fdc5231` Memory Album skin |
| `comments` / `perspectives` tables + author-only write RLS | Already in M1 |
| Photos INSERT `member + uploader_id = uid` | Already in M1; M4 author attach on capture |
| `profiles_select_own` (own id only) | **Must change in M5** |
| `albumTheme()` on `MaterialApp.router` | M4.5 |
| Timeline published cards; tap currently no-op | M4 + M4.5 |
| Cloud staging / Resend | Bill / Staging MS — local only |

## Spec match (M5)

| Exit criterion | Agent delivery |
|----------------|----------------|
| Published reader `/stories/:storyId` | `StoryReaderPage` |
| Comments vs Perspectives separate (US-6 / US-6a) | Two sections + overlay |
| Nested `profiles.display_name`; fallback `Member` | Co-member SELECT + PostgREST embed |
| Any-member attach pictures (US-4 remainder) | Reader `Add photos` → `PhotosGateway` |
| Comment/perspective authorship (§14.3) | pgTAP author-only UPDATE/DELETE |
| Two-family zero cross-read including profiles | Extend isolation tests |
| Checks | `flutter test`; `supabase test db` |

**PR title:** `feat(m05): Reader, comments, and perspectives` — do not claim Bill smoke closed until Bill runs it.

## Files to touch

### Create

| Path | Responsibility |
|------|----------------|
| `supabase/migrations/20260927000001_profiles_select_comember.sql` | Replace own-only profiles SELECT |
| `supabase/tests/profiles_comember_select.sql` | Co-member can read `display_name`; stranger cannot |
| `supabase/tests/comments_perspectives_authorship.sql` | Author-only UPDATE/DELETE; member INSERT; cross-family empty |
| `apps/tell_me_a_story/lib/data/comments_api.dart` | `Comment` + `CommentsGateway` / `CommentsApi` |
| `apps/tell_me_a_story/lib/data/perspectives_api.dart` | `Perspective` + `PerspectivesGateway` / `PerspectivesApi` |
| `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart` | Published reader |
| `apps/tell_me_a_story/lib/features/comments/comment_composer.dart` | Inline short comment + Post |
| `apps/tell_me_a_story/lib/features/perspectives/add_perspective_page.dart` | Overlay full telling |
| `apps/tell_me_a_story/test/comments_api_test.dart` | Parse nested profile; empty → `Member`; reject blank body |
| `apps/tell_me_a_story/test/perspectives_api_test.dart` | Same for perspectives |
| `apps/tell_me_a_story/test/story_reader_page_test.dart` | Load published; sections; comment; photo add; not-found |
| `apps/tell_me_a_story/test/add_perspective_page_test.dart` | Overlay copy + publish |
| `docs/superpowers/plans/2026-09-27-m5-reader-comments-perspectives.md` | This plan |

### Modify

| Path | Change |
|------|--------|
| `apps/tell_me_a_story/lib/core/router/app_router.dart` | `AppRoutes.story` + `storyPerspective`; inject new gateways |
| `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart` | Card tap → reader |
| `apps/tell_me_a_story/test/timeline_page_test.dart` | Tap navigates (fake router) |
| `apps/tell_me_a_story/test/router_test.dart` | New routes; fakes implement new gateways |
| `supabase/tests/rls_two_family_isolation.sql` | Assert comments/perspectives + stranger profile empty |
| `README.md` | M5 local smoke path |

### Do not touch

- Photos RLS / bucket / path shape
- Capture field order, drafts, invite Edge contracts
- Timeline Far/Mid/Near, Realtime, Search
- `stories.title`, perspective title column, photo captions

## Interfaces (later tasks consume these)

```dart
String displayNameOrMember(String? name) {
  final t = name?.trim() ?? '';
  return t.isEmpty ? 'Member' : t;
}

class Comment {
  const Comment({
    required this.id,
    required this.storyId,
    required this.familyId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorDisplayName,
  });
  final String id, storyId, familyId, authorId, body;
  final DateTime createdAt;
  final String? authorDisplayName;
  String get authorLabel => displayNameOrMember(authorDisplayName);
}

abstract class CommentsGateway {
  Future<List<Comment>> listForStory(String storyId);
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  });
  Future<void> update({required String id, required String body});
  Future<void> delete(String id);
}

class Perspective { /* same shape as Comment, table perspectives */ }

abstract class PerspectivesGateway {
  Future<List<Perspective>> listForStory(String storyId);
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  });
  Future<void> update({required String id, required String body});
  Future<void> delete(String id);
}
```

PostgREST select:

```
*, author:profiles!author_id(display_name)
```

Create requires non-empty trimmed `body`; `author_id` = current uid (RLS).

Reader load (published only):

```
stories.select(...).eq('id', id).eq('status', 'published').maybeSingle()
```

Null → not-found. Then parallel: people (existing), place (existing), `listPhotos`, `comments.listForStory`, `perspectives.listForStory`.

## Tasks

### Task 1: Profiles co-member SELECT + pgTAP

**Files:** create migration + `profiles_comember_select.sql`; modify `rls_two_family_isolation.sql`.

- [ ] Write failing pgTAP: two members of family A — B can `SELECT display_name` of A; user in family C cannot. Isolation file also asserts comments/perspectives of family B are empty for A, and A cannot SELECT B’s profile when they share no family.
- [ ] `supabase test db` — RED (own-only policy).
- [ ] Migration:

```sql
drop policy profiles_select_own on public.profiles;

create policy profiles_select_own_or_comember
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.memberships mine
      join public.memberships theirs
        on theirs.family_id = mine.family_id
      where mine.user_id = auth.uid()
        and theirs.user_id = profiles.id
    )
  );
```

- [ ] `supabase test db` GREEN. Commit.

### Task 2: Comments/perspectives authorship pgTAP

**Files:** `supabase/tests/comments_perspectives_authorship.sql`

- [ ] Member of family can INSERT own comment/perspective (`author_id = uid`).
- [ ] Other member cannot UPDATE/DELETE that row.
- [ ] Author can UPDATE/DELETE own row.
- [ ] Non-member INSERT fails.
- [ ] `supabase test db` GREEN. Commit.

### Task 3: CommentsGateway + PerspectivesGateway (TDD)

**Files:** `lib/data/comments_api.dart`, `lib/data/perspectives_api.dart` + unit tests.

- [ ] Failing tests: parse nested `author.display_name`; missing/blank → `Member`; `create` trims and rejects empty body (`ArgumentError`); list ordered by `created_at`.
- [ ] Implement gateways with injectable `SupabaseClient` (same pattern as `StoriesApi`).
- [ ] `flutter test` those files GREEN. Commit.

### Task 4: Routes + timeline tap

**Files:** `app_router.dart`, `timeline_page.dart`, router/timeline tests.

- [ ] `AppRoutes.story = '/stories/:storyId'` (must not match `/stories/new` — keep `newStory` as a **literal** route registered **before** the param route, as today).
- [ ] `AppRoutes.storyPerspective = '/stories/:storyId/perspective'`.
- [ ] Timeline `_PublishedRow` is tappable → `context.push('/stories/${story.id}')`.
- [ ] Widget tests: tap published card pushes reader; `/stories/new` still capture. Commit.

### Task 5: StoryReaderPage (published load + chrome)

**Files:** `story_reader_page.dart` + `story_reader_page_test.dart`.

Layout (album tokens, Stitch section order):

1. AppBar back `Timeline` (`context.go('/timeline')`)
2. Headline from body first line / `Untitled`
3. Timeframe chip label (reuse M4 decade helper)
4. People chips (names from `PeopleGateway`)
5. Place label + mini `PlaceMap` when `place_id` set
6. Story body (Literata)
7. Photos strip (reuse `PhotoStrip` / `Image.memory` via `downloadBytes`) + `Add photos`
8. **Perspectives** list + `+ Add your perspective`
9. **Comments** list + inline composer

States: loading spinner; not-found (draft/missing); load error SnackBar.

- [ ] Tests with fakes: published renders body + sections; draft id shows not-found (no body); empty comments/perspectives still show headers + CTAs; `Member` when profile name null.
- [ ] Implement. `flutter test` GREEN. Commit.

### Task 6: Comments composer

**Files:** `comment_composer.dart`; wire on reader.

- [ ] Placeholder `Share a short memory or note...`; button `Post`; empty Post is no-op (stay, no row).
- [ ] Success: append list, clear field.
- [ ] Failure: SnackBar (do not invent a new locked sentence).
- [ ] Own row: overflow → delete (author-only). Skip edit chrome if it bloats; delete is enough for §14 authorship in UI.
- [ ] Tests. Commit.

### Task 7: Add Perspective overlay

**Files:** `add_perspective_page.dart`; route builder.

- [ ] Open via `context.push('/stories/$id/perspective')` from `+ Add your perspective`.
- [ ] Copy from Stitch table above. Primary `Publish perspective` (terracotta). Secondary `Cancel` pops.
- [ ] Empty body: keep overlay (same pattern as blocked publish — do not invent a new banner; disable primary until trimmed body non-empty).
- [ ] Success: pop + reader reloads perspectives.
- [ ] Tests. Commit.

### Task 8: Any-member Add photos on reader

**Files:** reader + existing `PhotosGateway`.

- [ ] `Add photos` uses same gallery pick + compress + `uploadPhoto` as capture.
- [ ] Cap ~20; `STORAGE_FAILED` retry via existing photo retry UX.
- [ ] Tests: member upload called; at cap hides/disables add. Commit.

### Task 9: README smoke + PR

Local smoke (two magic-link users in one family if possible; single user still proves author path):

1. Publish a story from `/stories/new` (M4 path).
2. Timeline card → reader; body, people, place, photos visible.
3. Add a comment; it lists under **Comments** with display name or `Member`.
4. `+ Add your perspective` → overlay → `Publish perspective` → listed under **Perspectives** (not in Comments).
5. `Add photos` on reader attaches another image (≤20).
6. Open `/stories/<draft-id>` → not-found.
7. `flutter test` + `supabase test db` output in PR body.

- [ ] README M5 section. PR `feat(m05): Reader, comments, and perspectives`. Do not merge. Do not claim Bill smoke closed.

## Out of M5 (explicit)

- Stitch “Edit story” / author edit of published core (US-5 UI)
- Perspective title field; photo captions / “Archival Sepia” types
- Voice / cassette / Listen
- Print, Export PDF, Archive Settings, Archive ID, Volume, read-time
- Far/Mid/Near zoom, Realtime (M6)
- Search (M7)
- Invite polish, SMS, offline, video, public Storage
- New Edge Functions; denormalized names; photos RLS rewrite

## Risks

- **PostgREST embed + RLS:** nested `profiles` fails until Task 1 lands. Do not ship reader before the migration.
- **Route clash:** `/stories/new` vs `/stories/:storyId` — keep literal `new` route first.
- **Stitch vs schema:** ignore decorative keepsake chrome; do not invent columns.
- **Mugatu empty/error strings:** OPEN — reuse SnackBar / not-found, do not write new locked prose.

## Execution after approval

Worktree: `.worktrees/feat-m05-reader-comments-perspectives` on `feat/m05-reader-comments-perspectives` from latest `main`.

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks.

**2. Inline Execution** — this session, executing-plans with checkpoints.

# Phase 4e: Photos, notes, reader — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `PhotosApi`, `CommentsApi` and `PerspectivesApi` call the Serverpod client; the reader shows the existing delete action on any note whose server-computed `canDelete` is true (D4).

**Architecture:** Gateway shape per the Phase 4 index §Conventions: `XxxApi({server.Client? client})`, lazy `serverClient`, every call wrapped in `withServerErrors`, `fromDto` next to the domain class. Interfaces (`PhotosGateway`, `CommentsGateway`, `PerspectivesGateway`) keep their methods; `Comment` / `Perspective` gain `canDelete` (default false).

**Tech Stack:** Flutter, `tell_me_a_story_client` (`photo.*`, `note.*`, `media.get`), `FileUploader`.

Branch `feat/p4e-photos-notes` off `feat/p4-cutover`. Scope row: index §"4e Photos, notes, reader".

---

## File map

| File | Change |
|---|---|
| `lib/data/photos_api.dart` | `Photo.fromDto`; `PhotosApi({client, uploadBinary})` over `photo.list/startUpload/finishUpload/delete/setHero` and `media.get`. `uploaderId` becomes nullable (DTO: author account may be gone). Delete `Photo.fromJson`, `_editVersion`, `storyPhotoStoragePath` (server builds keys), `deleteAllForStory`, all Supabase seams. `storyPhotosBucket` stays only while 4c's `stories_api.dart` still reads it. |
| `lib/data/comments_api.dart` | `Comment.canDelete`, `Comment.fromNote(NoteDto)`; `note.*` with `NoteKind.comment`. `authorId` nullable. |
| `lib/data/perspectives_api.dart` | same with `NoteKind.perspective`. |
| `lib/data/stories_api.dart` (4c-owned, minimal) | `discard` no longer calls `deleteAllForStory` (server `story.delete` queues photo blobs); drop the `photos:` ctor seam. |
| `lib/features/stories/story_reader_page.dart` | delete shown on `canDelete`; edit only on own notes; carry `canDelete` through local edits; drop the `person.relationship` line. Live swap left to 4z (needs 4c's `ServerTimelineLive`). |
| `lib/features/comments/comment_composer.dart` | `CommentTile` shows the Edit item only when `onEdit` is given (so a steward sees Delete only). |
| `lib/features/perspectives/add_perspective_page.dart` | carry `canDelete` on edit. |
| `test/photos_api_test.dart` | keep compression, cap, hero order, copyWith; `fromDto` tests; upload seam test; delete storage tests. |
| `test/comments_api_test.dart`, `test/perspectives_api_test.dart` | `fromNote` tests replace `fromJson`. |
| `test/story_reader_page_test.dart` | own-note seeds get `canDelete: true`; new steward test. |
| `test/live/photos_api_live_test.dart`, `test/live/notes_live_test.dart` | live round trips. |

## Tasks

### Task 1: Notes map from `NoteDto`
- [ ] Write `fromNote` tests in `comments_api_test.dart` / `perspectives_api_test.dart` (ids as strings, `authorName` → `authorLabel`, null author → `Member`, `canDelete` copied). Run: fails (no `fromNote`).
- [ ] Implement `Comment.fromNote` / `Perspective.fromNote`, `canDelete`, gateways over `note.listForStory(id, kind:)`, `note.create`, `note.update`, `note.delete`, each in `withServerErrors`. Body validation stays before the network.
- [ ] Run tests: pass. Commit `feat(client): comments and perspectives on note endpoint`.

### Task 2: Photos on `photo.*`
- [ ] Write `Photo.fromDto` tests and an upload test with a fake `PhotoUploadBinary` returning false → `StorageFailedException`, using a `server.Client` against an unreachable host is NOT needed: the seam is called only after `startUpload`, so the upload test goes live (Task 4). Unit test: `fromDto` + kept helpers. Run: fails.
- [ ] Implement `PhotosApi`: `uploadPhoto` = compress → `startUpload(storyId, mime, len)` → `uploadBinary(ticket.uploadDescription, bytes)` (default `FileUploader(desc).uploadByteData`) → false ⇒ `StorageFailedException` → `finishUpload(storyId, ticket.photoId, sortOrder)`. `downloadBytes(key)` = `media.get`; null ⇒ `StorageFailedException(code: 'NOT_FOUND')`.
- [ ] `stories_api.dart`: `discard` deletes the row only. Run tests: pass. Commit `feat(client): photos on photo endpoint`.

### Task 3: Reader D4 + relationship line
- [ ] Add reader test: steward (`u-owner`) sees a menu with Delete but no Edit on another member's comment and perspective with `canDelete: true`; tapping Delete calls the gateway. Update own-note seeds to `canDelete: true`. Run: fails.
- [ ] Reader: comment `canDelete: row.canDelete`, `onEdit` only for own+`_canWrite`; perspective menu when own or `canDelete`, items filtered. Drop `relationship` chip text. Run: pass. Commit `feat(client): stewards delete others' notes (D4)`.

### Task 4: Live tests
- [ ] `test/live/photos_api_live_test.dart`: owner creates family + draft story, uploads two photos, lists (hero first), setHero, downloadBytes, deletePhoto.
- [ ] `test/live/notes_live_test.dart`: comments and perspectives CRUD; owner sees `canDelete` on member's note on a published story and deletes it; member sees `canDelete` false on owner's note.
- [ ] `just test-live` passes. Commit `test(client): photos and notes live tests`.

### Task 5: Gate
- [ ] `dart format --output=none --set-exit-if-changed lib test` 0 changed; `flutter analyze` ≤ 23; `flutter test`; `just test-live`.

## Left to others
- 4z: reader `SupabaseTimelineLive()` → `ServerTimelineLive()` (4c builds it).
- 4c / 4z: `storyPhotosBucket` goes when `stories_api.dart` stops downloading thumbs from Supabase storage.

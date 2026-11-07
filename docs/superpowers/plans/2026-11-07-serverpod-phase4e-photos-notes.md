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
| `test/photos_api_test.dart` | keep compression, cap, hero order, copyWith; `fromDto` tests replace `fromJson`; delete `storyPhotoStoragePath` and all storage/seam tests (the upload seam is exercised live). |
| `test/comments_api_test.dart`, `test/perspectives_api_test.dart` | `fromNote` tests replace `fromJson`; fakes carry `canDelete`. |
| `test/story_reader_page_test.dart`, `test/add_perspective_page_test.dart` | own-note seeds and fakes carry `canDelete: true`; new steward test. |
| `test/gateway_errors_test.dart` | delete the `StoriesApi.discard` photo-cleanup group (helper removed; whole file goes in 4z). |
| `test/live/photos_api_live_test.dart`, `test/live/notes_live_test.dart`, `test/live/support/story_fixture.dart` | live round trips; fixture builds a publishable story (date, person, place) and joins a member by invite. |

## Tasks

### Task 1: Notes map from `NoteDto`
- [x] Write `fromNote` tests in `comments_api_test.dart` / `perspectives_api_test.dart` (ids as strings, `authorName` → `authorLabel`, null author → `Member`, `canDelete` copied). Run: fails (no `fromNote`).
- [x] Implement `Comment.fromNote` / `Perspective.fromNote`, `canDelete`, gateways over `note.listForStory(id, kind:)`, `note.create`, `note.update`, `note.delete`, each in `withServerErrors`. Body validation stays before the network.
- [x] Run tests: pass. Commit `feat(client): comments and perspectives on note endpoint`.

### Task 2: Photos on `photo.*`
- [x] Rewrite `photos_api_test.dart`: `Photo.fromDto` tests (keys, nullable uploader, edited key) plus the kept helper tests. Run: fails (no `fromDto`). The upload seam needs a real `startUpload` ticket, so its refusal path is tested live (Task 4).
- [x] Implement `PhotosApi`: `uploadPhoto` = compress → `startUpload(storyId, mime, len)` → `uploadBinary(ticket.uploadDescription, bytes)` (default `FileUploader(desc).uploadByteData`) → false or throw ⇒ `StorageFailedException` → `finishUpload(storyId, ticket.photoId, sortOrder)`. The cap is the server's (`photoCap` → `StateError('PHOTO_CAP')`). `downloadBytes(key)` = `media.get`; null ⇒ `StorageFailedException(code: 'NOT_FOUND')`.
- [x] `stories_api.dart`: `discard` deletes the row only (no `photos:` seam). Run tests: pass. Commit `feat(client): photos on photo endpoint; drop deleteAllForStory`.

### Task 3: Reader D4 + relationship line
- [x] Add reader test: a steward (`u1`) sees a menu with Delete but no Edit on another member's comment and perspective with `canDelete: true`; tapping Delete calls the gateway. Own-note seeds get `canDelete: true`. Run: fails.
- [x] Reader: comment `canDelete: row.canDelete`, `onEdit` only for own+`_canWrite`; perspective menu when own or `canDelete`, items filtered. Drop the `relationship` chip text. Run: pass. Commit `feat(client): stewards delete others' notes (D4); drop relationship line`.

### Task 4: Live tests
- [x] `test/live/photos_api_live_test.dart`: upload two, list, setHero, downloadBytes, deletePhoto; refused upload (`uploadBinary` → false) is `StorageFailedException` with no row; unknown key is `NOT_FOUND`.
- [x] `test/live/notes_live_test.dart`: comments and perspectives CRUD; owner sees `canDelete` on a member's note on a published story and deletes it; member sees `canDelete` false on the owner's note and is refused.
- [x] `just test-live` passes (8). Commit `test(client): photos and notes live tests`.

### Task 5: Gate
- [x] `dart format --output=none --set-exit-if-changed lib test` 0 changed; `flutter analyze` 14 issues (≤ 23); `flutter test` 706 passed (1 skipped); `just test-live` 8 passed.

## Left to others
- 4z: reader `SupabaseTimelineLive()` → `ServerTimelineLive()` (4c builds it).
- 4c / 4z: `storyPhotosBucket` goes when `stories_api.dart` stops downloading thumbs from Supabase storage.

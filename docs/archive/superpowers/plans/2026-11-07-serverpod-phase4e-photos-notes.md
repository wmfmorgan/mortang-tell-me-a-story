# Phase 4e: Photos, notes, reader — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `PhotosApi`, `CommentsApi`, `PerspectivesApi` call Serverpod client; reader shows existing delete action on any note where server-computed `canDelete` true (D4).

**Architecture:** Gateway shape per Phase 4 index §Conventions: `XxxApi({server.Client? client})`, lazy `serverClient`, every call wrapped in `withServerErrors`, `fromDto` beside domain class. Interfaces (`PhotosGateway`, `CommentsGateway`, `PerspectivesGateway`) keep methods; `Comment` / `Perspective` gain `canDelete` (default false).

**Tech Stack:** Flutter, `tell_me_a_story_client` (`photo.*`, `note.*`, `media.get`), `FileUploader`.

Branch `feat/p4e-photos-notes` off `feat/p4-cutover`. Scope row: index §"4e Photos, notes, reader".

---

## File map

| File | Change |
|---|---|
| `lib/data/photos_api.dart` | `Photo.fromDto`; `PhotosApi({client, uploadBinary})` over `photo.list/startUpload/finishUpload/delete/setHero` + `media.get`. `uploaderId` nullable (DTO: author account may be gone). Delete `Photo.fromJson`, `_editVersion`, `storyPhotoStoragePath` (server builds keys), `deleteAllForStory`, all Supabase seams. `storyPhotosBucket` stays only while 4c's `stories_api.dart` still reads it. |
| `lib/data/comments_api.dart` | `Comment.canDelete`, `Comment.fromNote(NoteDto)`; `note.*` with `NoteKind.comment`. `authorId` nullable. |
| `lib/data/perspectives_api.dart` | Same, `NoteKind.perspective`. |
| `lib/data/stories_api.dart` (4c-owned, minimal) | `discard` stops calling `deleteAllForStory` (server `story.delete` queues photo blobs); drop `photos:` ctor seam. |
| `lib/features/stories/story_reader_page.dart` | Delete shown on `canDelete`; edit only own notes; carry `canDelete` through local edits; drop `person.relationship` line. Live swap left to 4z (needs 4c's `ServerTimelineLive`). |
| `lib/features/comments/comment_composer.dart` | `CommentTile` shows Edit item only when `onEdit` given (steward sees Delete only). |
| `lib/features/perspectives/add_perspective_page.dart` | Carry `canDelete` on edit. |
| `test/photos_api_test.dart` | Keep compression, cap, hero order, copyWith; `fromDto` tests replace `fromJson`; delete `storyPhotoStoragePath` + all storage/seam tests (upload seam exercised live). |
| `test/comments_api_test.dart`, `test/perspectives_api_test.dart` | `fromNote` tests replace `fromJson`; fakes carry `canDelete`. |
| `test/story_reader_page_test.dart`, `test/add_perspective_page_test.dart` | Own-note seeds + fakes carry `canDelete: true`; new steward test. |
| `test/gateway_errors_test.dart` | Delete `StoriesApi.discard` photo-cleanup group (helper removed; whole file goes in 4z). |
| `test/live/photos_api_live_test.dart`, `test/live/notes_live_test.dart`, `test/live/support/story_fixture.dart` | Live round trips; fixture builds publishable story (date, person, place), joins member by invite. |

## Tasks

### Task 1: Notes map from `NoteDto`
- [x] Write `fromNote` tests in `comments_api_test.dart` / `perspectives_api_test.dart` (ids as strings, `authorName` → `authorLabel`, null author → `Member`, `canDelete` copied). Run: fails (no `fromNote`).
- [x] Implement `Comment.fromNote` / `Perspective.fromNote`, `canDelete`, gateways over `note.listForStory(id, kind:)`, `note.create`, `note.update`, `note.delete`, each in `withServerErrors`. Body validation stays pre-network.
- [x] Run tests: pass. Commit `feat(client): comments and perspectives on note endpoint`.

### Task 2: Photos on `photo.*`
- [x] Rewrite `photos_api_test.dart`: `Photo.fromDto` tests (keys, nullable uploader, edited key) + kept helper tests. Run: fails (no `fromDto`). Upload seam needs real `startUpload` ticket, so refusal path tested live (Task 4).
- [x] Implement `PhotosApi`: `uploadPhoto` = compress → `startUpload(storyId, mime, len)` → `uploadBinary(ticket.uploadDescription, bytes)` (default `FileUploader(desc).uploadByteData`) → false or throw ⇒ `StorageFailedException` → `finishUpload(storyId, ticket.photoId, sortOrder)`. Cap is server's (`photoCap` → `StateError('PHOTO_CAP')`). `downloadBytes(key)` = `media.get`; null ⇒ `StorageFailedException(code: 'NOT_FOUND')`.
- [x] `stories_api.dart`: `discard` deletes row only (no `photos:` seam). Run tests: pass. Commit `feat(client): photos on photo endpoint; drop deleteAllForStory`.

### Task 3: Reader D4 + relationship line
- [x] Add reader test: steward (`u1`) sees menu with Delete, no Edit, on other member's comment + perspective with `canDelete: true`; tap Delete calls gateway. Own-note seeds get `canDelete: true`. Run: fails.
- [x] Reader: comment `canDelete: row.canDelete`, `onEdit` only for own+`_canWrite`; perspective menu when own or `canDelete`, items filtered. Drop `relationship` chip text. Run: pass. Commit `feat(client): stewards delete others' notes (D4); drop relationship line`.

### Task 4: Live tests
- [x] `test/live/photos_api_live_test.dart`: upload two, list, setHero, downloadBytes, deletePhoto; refused upload (`uploadBinary` → false) is `StorageFailedException`, no row; unknown key is `NOT_FOUND`.
- [x] `test/live/notes_live_test.dart`: comments + perspectives CRUD; owner sees `canDelete` on member's note on published story, deletes it; member sees `canDelete` false on owner's note, refused.
- [x] `just test-live` passes (8). Commit `test(client): photos and notes live tests`.

### Task 5: Gate
- [x] `dart format --output=none --set-exit-if-changed lib test` 0 changed; `flutter analyze` 14 issues (≤ 23); `flutter test` 706 passed (1 skipped); `just test-live` 8 passed.

## Left to others
- 4z: reader `SupabaseTimelineLive()` → `ServerTimelineLive()` (4c builds it).
- 4c / 4z: `storyPhotosBucket` goes when `stories_api.dart` stops downloading thumbs from Supabase storage.
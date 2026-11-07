# Phase 3d: Photos and Media Implementation Plan

> Executed 2026-11-07 on `feat/p3d-photos-media` (`a42f350`..`71c1f4f`), with server tests at 131/131 (100 foundation + 31 here). Code blocks below match what landed; deviations found while executing: `queued` uses a null-aware set element (lint), `_liveFamiliesOf` types its id set as `<UuidValue>{…}` (a bare literal infers `Set<UuidValue?>` and fails at runtime in `inSet`), and `dart format` re-wrapped `finishUpload`. The first `server-generate` also re-wrapped imports in already-committed client DTO files (generator output, no content change). The client package needs `dart pub get` once in a fresh worktree before `dart analyze`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `PhotoEndpoint` (`list`, `startUpload`, `finishUpload`, `delete`, `setHero`) and `MediaEndpoint` (`get`, `getMany`) on top of the landed Phase 3.0 foundation.

**Architecture:** Two endpoint files under `apps/server/lib/src/endpoints/`. Photo writes check `Authz` first, run in one transaction (story row locked `forNoKeyUpdate` where the cap or the order is at stake), queue old or rejected keys in `blob_deletions` in that transaction, and post a `photo` live event after commit for published stories only. Media reads find the row that holds each requested key (photos, family covers, person avatars, user avatars), check access for that row, and return bytes from the `private` storage; anything unknown or unauthorized is simply absent.

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1 (`serverpod`, `serverpod_test`), embedded Postgres 16, just.

**References (spec of record):**
- Phase 3 index `2026-11-07-serverpod-phase3-server-endpoints.md` §Conventions and row "3d Photos and media".
- `docs/migration/endpoint-contract.md` §2.0 (media finds the row holding the key), §2.2 `PhotoEndpoint`/`MediaEndpoint` signatures.
- `docs/migration/business-rules.md` §2.7 (all rows except save/reset edit), §4.5, §7 cases 25, 27, 46, 47, 78–83 (photo part), 90 (reads).
- `docs/migration/schema-design.md` §4.2 (upload flow, sniffing, limits), §4.3 (deletion queue).

All commands run from the worktree root (`/tmp/tmas-p3d-photos-media`) unless a step says otherwise.

---

## Decisions taken inside the slice

- **Authorization (business-rules §2.7).**
  - `list`: `canReadStory(story)`.
  - `startUpload`/`finishUpload` (attach): `canContribute(story)`; the uploader is the caller.
  - `delete` and `setHero` (reorder): `canContribute(story) AND (uploader OR canEditStory(story))`. `setHero` rewrites the whole story's `sortOrder` to `0..n-1` in one transaction (endpoint-contract §2.2); the rule is checked on the photo being promoted.
  - A missing story or photo is refused as `forbidden` like a stranger, so ids don't leak (index §Conventions).
- **Errors.** `forbidden()` (default text) for access. The photo cap is `AppException(photoCap, 'photo limit reached')` (index §Conventions; §7 case 78 says VALIDATION, the index is binding). Upload checks are `validation` with the texts `unsupported image type` (from `extForMime`/sniffing), `photo is empty`, `photo is too large`, `image type does not match`, `photo already added`. A missing or unverifiable upload is `AppException(storageFailed, 'upload not found')`. These upload texts are new: §5.2 has no upload catalogue because the old client wrote to Storage directly.
- **finishUpload has no `mimeType`** (contract signature). The server rebuilds the three candidate keys (`original.jpg|png|webp`) for `(story.familyId, storyId, photoId)` and verifies them in turn; the one that verifies is the upload, and its extension is the declared type the sniffed bytes must match. Nobody parses keys.
- **finishUpload failure paths queue the blob** in the same transaction that decides the failure (contract: "on any failure the blob is queued for deletion"). When nothing verifies, all three candidate keys are queued (deleting a missing key is a no-op). The one exception is a second finish for a photo row that already exists: that blob belongs to the row, so nothing is queued.
- **The cap is checked twice:** a cheap count at `startUpload`, and the binding count at `finishUpload` under the story row lock (schema-design §3.2 "Lock the story row forNoKeyUpdate, count photos, reject at ≥ 20").
- **Media.** Cover: `isLiveMember(family)` (D6b). Person avatar: `isTreeMemberOf(person.treeId)` (D8). User avatar: self, or both are members of one live family. Photo original/edited: `canReadStory(story)`. A key whose row exists but whose blob is missing is treated like an unknown key.

## File map

| Path | Responsibility |
|---|---|
| `apps/server/lib/src/endpoints/photo_endpoint.dart` | `PhotoEndpoint`: list, upload ticket, finish (verify, sniff, cap, insert), delete, hero order; live events |
| `apps/server/lib/src/endpoints/media_endpoint.dart` | `MediaEndpoint`: `get`, `getMany`, and the private `_MediaAccess` key-to-row authorization |
| `apps/server/test/integration/support/photo_fixtures.dart` | Slice-only builders: image bytes, stored blobs, simulated client upload, photo rows, covers, avatars, origin branch, queued-key lookup, live event capture |
| `apps/server/test/integration/photo_endpoint_test.dart` | PhotoEndpoint tests (BR 27, 46, 47, 78, 79, 81, 82, 83) |
| `apps/server/test/integration/media_endpoint_test.dart` | MediaEndpoint tests (BR 25, 80, 90) |
| generated: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart` | Regenerated by `mise exec -- just server-generate` |

§7 cases → tests:

| Case | Test (file) |
|---|---|
| 25 (cover read part) | `BR 25` (media) |
| 27 (photo part) | `BR 27` (photo) |
| 46 | `BR 46` (photo) |
| 47 | `BR 47` (photo) |
| 78 | `BR 78` ×2 (photo) |
| 79 (photo part) | `BR 79` (photo) |
| 80 | `BR 80` ×2 (media) |
| 81 (photo) | `BR 81` ×2 (photo) |
| 82 | `BR 82` (photo) |
| 83 (photo part) | `BR 83` (photo) |
| 90 (reads) | `BR 90` (media) |

Case 79 is enforced structurally: `familyId` isn't stored and keys are built from the story, so the port checks that a photo uploaded for story A can't be finished against story B. Case 80 ports to media: malformed or unknown keys return nothing and raise nothing. Case 81: the API has no generic photo update; the only client-changeable field is `sortOrder`, through `setHero`, so the port checks that `setHero` changes `sortOrder` only and is allowed for the uploader or an editor.

---

### Task 1: Slice fixtures and `PhotoEndpoint.list`

**Files:**
- Create: `apps/server/test/integration/support/photo_fixtures.dart`
- Create: `apps/server/test/integration/photo_endpoint_test.dart`
- Create: `apps/server/lib/src/endpoints/photo_endpoint.dart`
- Generated: see file map

- [ ] **Step 1: Write the slice fixtures**

`apps/server/test/integration/support/photo_fixtures.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';

import 'fixtures.dart';

/// Bytes whose magic numbers `sniffImageMime` recognizes.
ByteData jpegBytes() => _bytes(const [0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 1, 2]);
ByteData pngBytes() =>
    _bytes(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]);
ByteData textBytes() => _bytes('not an image'.codeUnits);

ByteData _bytes(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

List<int> bytesOf(ByteData data) => Uint8List.sublistView(data).toList();

/// Slice 3d builders on top of [Fx].
extension PhotoFx on Fx {
  /// Stores [data] (default: JPEG bytes) at [key] as a verified blob.
  Future<void> blob(String key, [ByteData? data]) => s.storage.storeFile(
    storageId: blobStorageId,
    path: key,
    byteData: data ?? jpegBytes(),
  );

  /// Leaves [data] at [key] the way the client's `FileUploader` does: present
  /// but unverified until `finishUpload` calls `verifyUpload`.
  Future<void> clientUpload(String key, ByteData data) =>
      DatabaseCloudStorage(blobStorageId).storeUnverifiedFile(
        session: s,
        path: key,
        byteData: data,
      );

  Future<bool> blobExists(String key) =>
      s.storage.fileExists(storageId: blobStorageId, path: key);

  /// A JPEG photo row on [story] with its blob stored; [edited] adds a stored
  /// edited version 1.
  Future<Photo> photo(
    Story story, {
    UuidValue? uploaderId,
    int sortOrder = 0,
    bool edited = false,
  }) async {
    final id = const Uuid().v7obj();
    final original = photoOriginalKey(
      familyId: story.familyId,
      storyId: story.id!,
      photoId: id,
      mimeType: 'image/jpeg',
    );
    await blob(original);
    String? editedKey;
    if (edited) {
      editedKey = photoEditedKey(
        familyId: story.familyId,
        storyId: story.id!,
        photoId: id,
        editVersion: 1,
      );
      await blob(editedKey, pngBytes());
    }
    return Photo.db.insertRow(
      s,
      Photo(
        id: id,
        storyId: story.id!,
        uploaderId: uploaderId,
        originalKey: original,
        editedKey: editedKey,
        editVersion: edited ? 1 : 0,
        sortOrder: sortOrder,
      ),
    );
  }

  /// A live branch of [parent] in the same tree whose origin is [origin].
  Future<Family> branch(Family parent, Story origin) async {
    final child = await family(
      Tree(id: parent.treeId),
      parentId: parent.id,
      name: 'Branch',
    );
    return Family.db.updateRow(s, child.copyWith(originStoryId: origin.id));
  }

  /// Gives [target] a stored cover blob and returns its key.
  Future<String> cover(Family target) async {
    final key = familyCoverKey(familyId: target.id!, mimeType: 'image/jpeg');
    await blob(key);
    await Family.db.updateRow(s, target.copyWith(coverKey: key));
    return key;
  }

  /// Gives [person] a stored avatar blob and returns its key.
  Future<String> personAvatar(Person person) async {
    final key = personAvatarKey(treeId: person.treeId, personId: person.id!);
    await blob(key);
    await Person.db.updateRow(s, person.copyWith(avatarKey: key));
    return key;
  }

  /// Gives [user]'s app profile a stored avatar blob and returns its key.
  Future<String> userAvatar(UuidValue user) async {
    final key = userAvatarKey(authUserId: user);
    await blob(key);
    final appUser = await AppUser.db.findFirstRow(
      s,
      where: (t) => t.authUserId.equals(user),
    );
    await AppUser.db.updateRow(s, appUser!.copyWith(avatarKey: key));
    return key;
  }

  Future<void> softDelete(Family target) => Family.db.updateRow(
    s,
    target.copyWith(deletedAt: DateTime.now().toUtc()),
  );

  /// The keys among [keys] that are queued in `blob_deletions`.
  Future<Set<String>> queued(Iterable<String?> keys) async {
    final wanted = {for (final key in keys) ?key};
    final rows = await BlobDeletion.db.find(
      s,
      where: (t) => t.key.inSet(wanted),
    );
    return {for (final row in rows) row.key};
  }

  /// The live events posted on [family]'s channel while [action] runs.
  Future<List<LiveEventDto>> eventsDuring(
    Family family,
    Future<void> Function() action,
  ) async {
    final events = <LiveEventDto>[];
    final sub = s.messages
        .createStream<LiveEventDto>(familyChannel(family.id!))
        .listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    return events;
  }
}
```

- [ ] **Step 2: Write the failing tests for `list`**

`apps/server/test/integration/photo_endpoint_test.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/photo_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given PhotoEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    /// A live family with [members] and a story by [author].
    Future<(Family, Story)> familyStory(
      UuidValue author, {
      List<UuidValue> members = const [],
      StoryStatus status = StoryStatus.published,
      MembershipRole authorRole = MembershipRole.member,
    }) async {
      final family = await fx.family(await fx.tree());
      await fx.join(family, author, authorRole);
      for (final member in members) {
        await fx.join(family, member);
      }
      final story = await fx.story(family, authorId: author, status: status);
      return (family, story);
    }

    test('when an anonymous caller lists then unauthenticated', () async {
      final story = (await familyStory(await fx.user())).$2;
      await expectLater(
        endpoints.photo.list(sessionBuilder, story.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test(
      'when a member lists a published story then photos come hero first '
      'with the familyId derived from the story',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);
        final second = await fx.photo(story, sortOrder: 1);
        final hero = await fx.photo(story, sortOrder: 0);

        final photos = await endpoints.photo.list(
          asUser(sessionBuilder, member),
          story.id!,
        );

        expect(photos.map((p) => p.id), [hero.id, second.id]);
        expect(photos.first.familyId, family.id);
        expect(photos.first.originalKey, hero.originalKey);
      },
    );

    test(
      'when a tree reader lists a published story then allowed; '
      'a draft, a non-author on a draft or a stranger then FORBIDDEN',
      () async {
        final author = await fx.user();
        final other = await fx.user();
        final reader = await fx.user();
        final (family, published) = await familyStory(
          author,
          members: [other],
        );
        final draft = await fx.story(
          family,
          authorId: author,
          status: StoryStatus.draft,
        );
        final child = await fx.family(
          Tree(id: family.treeId),
          parentId: family.id,
        );
        await fx.join(child, reader);
        await fx.photo(published);

        expect(
          await endpoints.photo.list(
            asUser(sessionBuilder, reader),
            published.id!,
          ),
          hasLength(1),
        );
        for (final (user, story) in [
          (reader, draft),
          (other, draft),
          (await fx.user(), published),
        ]) {
          await expectLater(
            endpoints.photo.list(asUser(sessionBuilder, user), story.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        }
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: compile error, `The getter 'photo' isn't defined for the type 'TestEndpoints'`.

- [ ] **Step 4: Implement `list`**

`apps/server/lib/src/endpoints/photo_endpoint.dart`:

```dart
import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// Story photos (business-rules.md §2.7 without edit save/reset, §4.5; upload
/// flow schema-design.md §4.2).
class PhotoEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The story's photos, hero first.
  Future<List<PhotoDto>> list(Session session, UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canReadStory(story)) {
      throw forbidden();
    }
    final rows = await Photo.db.find(
      session,
      where: (t) => t.storyId.equals(storyId),
      orderByList: _order,
    );
    return [for (final photo in rows) _dto(photo, story)];
  }

  static List<Order> _order(PhotoTable t) => [
    t.sortOrder.asc(),
    t.createdAt.asc(),
    t.id.asc(),
  ];

  static PhotoDto _dto(Photo photo, Story story) => PhotoDto(
    id: photo.id!,
    storyId: photo.storyId,
    familyId: story.familyId,
    uploaderId: photo.uploaderId,
    originalKey: photo.originalKey,
    editedKey: photo.editedKey,
    editVersion: photo.editVersion,
    sortOrder: photo.sortOrder,
  );
}
```

Then: `mise exec -- just server-generate`.

- [ ] **Step 5: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): PhotoEndpoint.list"
```

### Task 2: `PhotoEndpoint.startUpload`

**Files:**
- Modify: `apps/server/lib/src/endpoints/photo_endpoint.dart`
- Test: `apps/server/test/integration/photo_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests** (append inside the `withServerpod` body)

```dart
    test(
      'when a member starts an upload then the ticket names a fresh key '
      "under the story's family",
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);

        final ticket = await endpoints.photo.startUpload(
          asUser(sessionBuilder, member),
          story.id!,
          'image/png',
          100,
        );

        expect(
          ticket.key,
          'families/${family.id}/stories/${story.id}/photos/'
          '${ticket.photoId}/original.png',
        );
        expect(ticket.uploadDescription, isNotEmpty);
      },
    );

    test(
      'when the type is unsupported or the size is out of range '
      'then VALIDATION',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final as = asUser(sessionBuilder, member);
        for (final (mime, size, message) in [
          ('image/gif', 100, 'unsupported image type'),
          ('image/jpeg', 0, 'photo is empty'),
          ('image/jpeg', photoMaxBytes + 1, 'photo is too large'),
        ]) {
          await expectLater(
            endpoints.photo.startUpload(as, story.id!, mime, size),
            throwsAppError(AppErrorCode.validation, message),
          );
        }
      },
    );

    // BR 78
    test(
      'Given story with 20 photos, when attaching 21st, '
      'then "photo limit reached"',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        for (var i = 0; i < 20; i++) {
          await fx.photo(story, sortOrder: i);
        }
        await expectLater(
          endpoints.photo.startUpload(
            asUser(sessionBuilder, member),
            story.id!,
            'image/jpeg',
            100,
          ),
          throwsAppError(AppErrorCode.photoCap, 'photo limit reached'),
        );
      },
    );

    // BR 27
    test(
      'Given parent member (tree reader), when inserting photo on child '
      'story, then refused',
      () async {
        final parentMember = await fx.user();
        final childMember = await fx.user();
        final parent = await fx.family(await fx.tree());
        await fx.join(parent, parentMember);
        final child = await fx.family(
          Tree(id: parent.treeId),
          parentId: parent.id,
        );
        await fx.join(child, childMember);
        final story = await fx.story(child, authorId: childMember);

        await expectLater(
          endpoints.photo.startUpload(
            asUser(sessionBuilder, parentMember),
            story.id!,
            'image/jpeg',
            100,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: compile error, `The method 'startUpload' isn't defined`.

- [ ] **Step 3: Implement `startUpload`**

Add imports `import '../media/blob_keys.dart';` and, inside the class:

```dart
  /// Photos per story (business-rules.md §4.5).
  static const maxPhotos = 20;

  /// Authorizes an upload of [byteLength] bytes of [mimeType] and returns the
  /// server-built key with its upload description.
  Future<PhotoUploadTicketDto> startUpload(
    Session session,
    UuidValue storyId,
    String mimeType,
    int byteLength,
  ) async {
    final story = await _contributable(session, storyId);
    final photoId = const Uuid().v7obj();
    final key = photoOriginalKey(
      familyId: story.familyId,
      storyId: storyId,
      photoId: photoId,
      mimeType: mimeType,
    );
    if (byteLength <= 0) throw validation('photo is empty');
    if (byteLength > photoMaxBytes) throw validation('photo is too large');
    final count = await Photo.db.count(
      session,
      where: (t) => t.storyId.equals(storyId),
    );
    if (count >= maxPhotos) throw _photoCap();
    final description = await session.storage.createUploadDescription(
      storageId: blobStorageId,
      path: key,
      options: UploadOptions(
        maxFileSize: photoMaxBytes,
        contentLength: byteLength,
        preventOverwrite: true,
      ),
    );
    return PhotoUploadTicketDto(
      photoId: photoId,
      key: key,
      uploadDescription: description,
    );
  }

  /// The story when the caller may add photos to it (`canContribute`).
  Future<Story> _contributable(Session session, UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canContribute(story)) {
      throw forbidden();
    }
    return story;
  }

  static AppException _photoCap() =>
      AppException(code: AppErrorCode.photoCap, message: 'photo limit reached');
```

Then: `mise exec -- just server-generate`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): PhotoEndpoint.startUpload"
```

### Task 3: `PhotoEndpoint.finishUpload`

**Files:**
- Modify: `apps/server/lib/src/endpoints/photo_endpoint.dart`
- Test: `apps/server/test/integration/photo_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests** (append inside the `withServerpod` body, after the helper `familyStory`; the helper `upload` goes right below `familyStory`)

```dart
    /// startUpload + client upload of [data] + finishUpload, as [user].
    Future<PhotoDto> upload(
      UuidValue user,
      Story story, {
      String mimeType = 'image/jpeg',
      ByteData? data,
      int sortOrder = 0,
    }) async {
      final bytes = data ?? jpegBytes();
      final as = asUser(sessionBuilder, user);
      final ticket = await endpoints.photo.startUpload(
        as,
        story.id!,
        mimeType,
        bytes.lengthInBytes,
      );
      await fx.clientUpload(ticket.key, bytes);
      return endpoints.photo.finishUpload(
        as,
        story.id!,
        ticket.photoId,
        sortOrder,
      );
    }
```

```dart
    test(
      'when a member finishes an upload then the row is written with the '
      'caller as uploader and the blob is verified',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);

        final dto = await upload(member, story, sortOrder: 3);

        final row = await Photo.db.findById(fx.s, dto.id);
        expect(row!.uploaderId, member);
        expect(row.sortOrder, 3);
        expect(row.originalKey, dto.originalKey);
        expect(dto.familyId, family.id);
        expect(dto.originalKey, endsWith('/${dto.id}/original.jpg'));
        expect(await fx.blobExists(dto.originalKey), isTrue);
      },
    );

    test(
      'when the bytes are not an image or differ from the declared type '
      'then VALIDATION, no row, and the blob is queued',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final as = asUser(sessionBuilder, member);
        for (final (mime, data, message) in [
          ('image/jpeg', textBytes(), 'unsupported image type'),
          ('image/png', jpegBytes(), 'image type does not match'),
        ]) {
          final ticket = await endpoints.photo.startUpload(
            as,
            story.id!,
            mime,
            data.lengthInBytes,
          );
          await fx.clientUpload(ticket.key, data);
          await expectLater(
            endpoints.photo.finishUpload(as, story.id!, ticket.photoId, 0),
            throwsAppError(AppErrorCode.validation, message),
          );
          expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
          expect(await fx.queued([ticket.key]), {ticket.key});
        }
      },
    );

    test(
      'when nothing was uploaded then STORAGE_FAILED and no row',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final as = asUser(sessionBuilder, member);
        final ticket = await endpoints.photo.startUpload(
          as,
          story.id!,
          'image/jpeg',
          10,
        );
        await expectLater(
          endpoints.photo.finishUpload(as, story.id!, ticket.photoId, 0),
          throwsAppError(AppErrorCode.storageFailed, 'upload not found'),
        );
        expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
      },
    );

    test(
      'when the same upload is finished twice then VALIDATION and the '
      "row's blob is not queued",
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        final dto = await upload(member, story);

        await expectLater(
          endpoints.photo.finishUpload(
            asUser(sessionBuilder, member),
            story.id!,
            dto.id,
            0,
          ),
          throwsAppError(AppErrorCode.validation, 'photo already added'),
        );
        expect(await fx.queued([dto.originalKey]), isEmpty);
        expect(await fx.blobExists(dto.originalKey), isTrue);
      },
    );

    // BR 78
    test(
      'Given story at 19 photos, when another photo lands between start and '
      'finish, then "photo limit reached" and the blob is queued',
      () async {
        final member = await fx.user();
        final story = (await familyStory(member)).$2;
        for (var i = 0; i < 19; i++) {
          await fx.photo(story, sortOrder: i);
        }
        final as = asUser(sessionBuilder, member);
        final ticket = await endpoints.photo.startUpload(
          as,
          story.id!,
          'image/jpeg',
          jpegBytes().lengthInBytes,
        );
        await fx.clientUpload(ticket.key, jpegBytes());
        await fx.photo(story, sortOrder: 19);

        await expectLater(
          endpoints.photo.finishUpload(as, story.id!, ticket.photoId, 20),
          throwsAppError(AppErrorCode.photoCap, 'photo limit reached'),
        );
        expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
        expect(await fx.queued([ticket.key]), {ticket.key});
      },
    );

    // BR 79
    test(
      'Given photo uploaded for story A, when finished against story B of '
      'the same family, then refused and no row',
      () async {
        final member = await fx.user();
        final (family, a) = await familyStory(member);
        final b = await fx.story(family, authorId: member);
        final as = asUser(sessionBuilder, member);
        final ticket = await endpoints.photo.startUpload(
          as,
          a.id!,
          'image/jpeg',
          jpegBytes().lengthInBytes,
        );
        await fx.clientUpload(ticket.key, jpegBytes());

        await expectLater(
          endpoints.photo.finishUpload(as, b.id!, ticket.photoId, 0),
          throwsAppError(AppErrorCode.storageFailed, 'upload not found'),
        );
        expect(await Photo.db.findById(fx.s, ticket.photoId), isNull);
      },
    );

    // BR 46
    test(
      'Given child member, when uploading for the origin story, then the key '
      'is under the parent family (never a child-family path); on any other '
      'parent story, then refused',
      () async {
        final parentAuthor = await fx.user();
        final childMember = await fx.user();
        final (parent, origin) = await familyStory(parentAuthor);
        final other = await fx.story(parent, authorId: parentAuthor);
        final child = await fx.branch(parent, origin);
        await fx.join(child, childMember);

        final dto = await upload(childMember, origin);

        expect(dto.familyId, parent.id);
        expect(dto.originalKey, startsWith('families/${parent.id}/'));
        expect(dto.originalKey, isNot(contains('${child.id}')));
        await expectLater(
          endpoints.photo.startUpload(
            asUser(sessionBuilder, childMember),
            other.id!,
            'image/jpeg',
            100,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test(
      'when a photo is added to a published story then a photo event posts; '
      'on a draft nothing posts',
      () async {
        final member = await fx.user();
        final (family, published) = await familyStory(member);
        final draft = await fx.story(
          family,
          authorId: member,
          status: StoryStatus.draft,
        );

        final events = await fx.eventsDuring(
          family,
          () => upload(member, published),
        );
        expect(events, hasLength(1));
        expect(events.single.kind, LiveKind.photo);
        expect(events.single.storyId, published.id);
        expect(events.single.deleted, isFalse);

        expect(
          await fx.eventsDuring(family, () => upload(member, draft)),
          isEmpty,
        );
      },
    );
```

Also add `import 'dart:typed_data';` at the top of the test file.

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: compile error, `The method 'finishUpload' isn't defined`.

- [ ] **Step 3: Implement `finishUpload`**

Add imports `import '../live/live_events.dart';` and `import '../media/blob_outbox.dart';`, and inside the class:

```dart
  /// The image types a story photo may have.
  static const _mimeTypes = ['image/jpeg', 'image/png', 'image/webp'];

  /// Verifies the uploaded blob for [photoId], checks its bytes and the cap,
  /// and writes the row. On any failure the blob is queued for deletion,
  /// except when the row already exists (the blob is that row's).
  Future<PhotoDto> finishUpload(
    Session session,
    UuidValue storyId,
    UuidValue photoId,
    int sortOrder,
  ) async {
    final story = await _contributable(session, storyId);
    final uploaderId = Authz(session).requireUser();
    final (
      photo,
      error,
    ) = await session.db.transaction<(Photo?, AppException?)>((t) async {
      // Serializes the cap count and the double-finish check per story.
      await Story.db.findById(
        session,
        storyId,
        transaction: t,
        lockMode: LockMode.forNoKeyUpdate,
      );
      if (await Photo.db.findById(session, photoId, transaction: t) != null) {
        return (null, validation('photo already added'));
      }
      final keys = {
        for (final mime in _mimeTypes)
          mime: photoOriginalKey(
            familyId: story.familyId,
            storyId: storyId,
            photoId: photoId,
            mimeType: mime,
          ),
      };
      String? declared;
      for (final MapEntry(key: mime, value: key) in keys.entries) {
        if (await session.storage.verifyUpload(
          storageId: blobStorageId,
          path: key,
        )) {
          declared = mime;
          break;
        }
      }
      if (declared == null) {
        await queueBlobDeletions(session, keys.values, transaction: t);
        return (
          null,
          AppException(
            code: AppErrorCode.storageFailed,
            message: 'upload not found',
          ),
        );
      }
      final key = keys[declared]!;
      final refused = await _checkUpload(
        session,
        storyId,
        key,
        declared,
        t,
      );
      if (refused != null) {
        await queueBlobDeletions(session, [key], transaction: t);
        return (null, refused);
      }
      final row = await Photo.db.insertRow(
        session,
        Photo(
          id: photoId,
          storyId: storyId,
          uploaderId: uploaderId,
          originalKey: key,
          sortOrder: sortOrder,
        ),
        transaction: t,
      );
      return (row, null);
    });
    if (error != null) throw error;
    await _postIfPublished(session, story, deleted: false);
    return _dto(photo!, story);
  }

  /// Why the verified blob at [key] can't become a photo of its story, or
  /// null: size, sniffed type against [declared], then the cap (under the
  /// story lock held by [t]).
  Future<AppException?> _checkUpload(
    Session session,
    UuidValue storyId,
    String key,
    String declared,
    Transaction t,
  ) async {
    final ByteData bytes;
    try {
      bytes = await session.storage.retrieveFile(
        storageId: blobStorageId,
        path: key,
      );
    } on CloudStorageException {
      return AppException(
        code: AppErrorCode.storageFailed,
        message: 'upload not found',
      );
    }
    if (bytes.lengthInBytes > photoMaxBytes) {
      return validation('photo is too large');
    }
    final sniffed = sniffImageMime(bytes);
    if (sniffed == null) return validation('unsupported image type');
    if (sniffed != declared) return validation('image type does not match');
    final count = await Photo.db.count(
      session,
      where: (p) => p.storyId.equals(storyId),
      transaction: t,
    );
    return count >= maxPhotos ? _photoCap() : null;
  }

  /// Posts a `photo` event for a published [story]; drafts post nothing.
  Future<void> _postIfPublished(
    Session session,
    Story story, {
    required bool deleted,
  }) async {
    if (story.status != StoryStatus.published) return;
    await postLiveEvent(
      session,
      LiveEventDto(
        familyId: story.familyId,
        storyId: story.id,
        kind: LiveKind.photo,
        storyStatus: story.status,
        deleted: deleted,
      ),
    );
  }
```


Also add `import 'dart:typed_data';` at the top of the endpoint file (for `ByteData`).

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: 15 tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): PhotoEndpoint.finishUpload verifies, sniffs and caps"
```

### Task 4: `PhotoEndpoint.delete`

**Files:**
- Modify: `apps/server/lib/src/endpoints/photo_endpoint.dart`
- Test: `apps/server/test/integration/photo_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
    // BR 47
    test(
      "Given child member, when deleting a parent member's photo, then "
      'refused and nothing changes; can delete own uploaded photo and blob',
      () async {
        final parentMember = await fx.user();
        final childMember = await fx.user();
        final (parent, origin) = await familyStory(parentMember);
        final child = await fx.branch(parent, origin);
        await fx.join(child, childMember);
        final theirs = await fx.photo(origin, uploaderId: parentMember);
        final mine = await fx.photo(origin, uploaderId: childMember);
        final as = asUser(sessionBuilder, childMember);

        await expectLater(
          endpoints.photo.delete(as, theirs.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(await Photo.db.findById(fx.s, theirs.id!), isNotNull);
        expect(await fx.queued([theirs.originalKey]), isEmpty);

        await endpoints.photo.delete(as, mine.id!);
        expect(await Photo.db.findById(fx.s, mine.id!), isNull);
        expect(await fx.queued([mine.originalKey]), {mine.originalKey});
      },
    );

    // BR 82
    test(
      "Given parent owner, then can delete a child contributor's photo row "
      'and blobs on the published origin story; child-timeline owner '
      'deletes no parent photos',
      () async {
        final parentOwner = await fx.user();
        final childOwner = await fx.user();
        final (parent, origin) = await familyStory(
          parentOwner,
          authorRole: MembershipRole.owner,
        );
        final child = await fx.branch(parent, origin);
        await fx.join(child, childOwner, MembershipRole.owner);
        final contributed = await fx.photo(
          origin,
          uploaderId: childOwner,
          edited: true,
        );
        final parentPhoto = await fx.photo(origin, uploaderId: parentOwner);

        await expectLater(
          endpoints.photo.delete(
            asUser(sessionBuilder, childOwner),
            parentPhoto.id!,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(await Photo.db.findById(fx.s, parentPhoto.id!), isNotNull);

        await endpoints.photo.delete(
          asUser(sessionBuilder, parentOwner),
          contributed.id!,
        );
        expect(await Photo.db.findById(fx.s, contributed.id!), isNull);
        expect(
          await fx.queued([contributed.originalKey, contributed.editedKey]),
          {contributed.originalKey, contributed.editedKey},
        );
      },
    );

    // BR 83
    test(
      "Given story D reverted to draft with member B's photo on it, when B "
      "deletes it, then nothing changes; author A can delete A's own photo "
      'on D; on published P, B deletes own photo and blob',
      () async {
        final a = await fx.user();
        final b = await fx.user();
        final (family, published) = await familyStory(a, members: [b]);
        final draft = await fx.story(
          family,
          authorId: a,
          status: StoryStatus.draft,
        );
        final bsOnDraft = await fx.photo(draft, uploaderId: b);
        final asOnDraft = await fx.photo(draft, uploaderId: a);
        final bsOnPublished = await fx.photo(published, uploaderId: b);

        await expectLater(
          endpoints.photo.delete(asUser(sessionBuilder, b), bsOnDraft.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(await Photo.db.findById(fx.s, bsOnDraft.id!), isNotNull);

        await endpoints.photo.delete(asUser(sessionBuilder, a), asOnDraft.id!);
        expect(await Photo.db.findById(fx.s, asOnDraft.id!), isNull);

        await endpoints.photo.delete(
          asUser(sessionBuilder, b),
          bsOnPublished.id!,
        );
        expect(await Photo.db.findById(fx.s, bsOnPublished.id!), isNull);
        expect(await fx.queued([bsOnPublished.originalKey]), {
          bsOnPublished.originalKey,
        });
      },
    );

    test('when deleting a missing photo then FORBIDDEN', () async {
      await expectLater(
        endpoints.photo.delete(
          asUser(sessionBuilder, await fx.user()),
          const Uuid().v7obj(),
        ),
        throwsAppError(AppErrorCode.forbidden),
      );
    });

    test(
      'when a photo of a published story is deleted then a deleted photo '
      'event posts',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);
        final photo = await fx.photo(story, uploaderId: member);

        final events = await fx.eventsDuring(
          family,
          () => endpoints.photo.delete(
            asUser(sessionBuilder, member),
            photo.id!,
          ),
        );
        expect(events, hasLength(1));
        expect(events.single.kind, LiveKind.photo);
        expect(events.single.deleted, isTrue);
      },
    );
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: compile error, `The method 'delete' isn't defined`.

- [ ] **Step 3: Implement `delete`**

```dart
  /// Deletes the row; its original and edited keys are queued in the same
  /// transaction.
  Future<void> delete(Session session, UuidValue photoId) async {
    final photo = await Photo.db.findById(session, photoId);
    final story = photo == null
        ? null
        : await Story.db.findById(session, photo.storyId);
    if (photo == null ||
        story == null ||
        !await _canChange(session, story, photo)) {
      throw forbidden();
    }
    await session.db.transaction((t) async {
      final deleted = await Photo.db.deleteWhere(
        session,
        where: (p) => p.id.equals(photoId),
        transaction: t,
      );
      await queueBlobDeletions(session, [
        for (final row in deleted) ...[row.originalKey, row.editedKey],
      ], transaction: t);
    });
    await _postIfPublished(session, story, deleted: true);
  }

  /// Delete and reorder: `canContribute` AND (uploader OR `canEditStory`)
  /// (business-rules.md §2.7).
  Future<bool> _canChange(Session session, Story story, Photo photo) async {
    final authz = Authz(session);
    final uid = authz.userId;
    final mayTouch =
        (uid != null && photo.uploaderId == uid) ||
        await authz.canEditStory(story);
    return mayTouch && await authz.canContribute(story);
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: 20 tests pass.

- [ ] **Step 5: Commit** (regenerate first: `mise exec -- just server-generate`)

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): PhotoEndpoint.delete queues blobs"
```

### Task 5: `PhotoEndpoint.setHero`

**Files:**
- Modify: `apps/server/lib/src/endpoints/photo_endpoint.dart`
- Test: `apps/server/test/integration/photo_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
    // BR 81
    test(
      'Given photos, when the uploader makes one the hero, then sortOrder '
      'becomes 0..n-1 with it first and no other field changes',
      () async {
        final member = await fx.user();
        final (family, story) = await familyStory(member);
        final p1 = await fx.photo(story, uploaderId: member, sortOrder: 0);
        final p2 = await fx.photo(story, uploaderId: member, sortOrder: 5);
        final p3 = await fx.photo(
          story,
          uploaderId: member,
          sortOrder: 9,
          edited: true,
        );

        final events = await fx.eventsDuring(
          family,
          () => endpoints.photo.setHero(
            asUser(sessionBuilder, member),
            story.id!,
            p3.id!,
          ),
        );

        final rows = await Photo.db.find(
          fx.s,
          where: (t) => t.storyId.equals(story.id!),
          orderBy: (t) => t.sortOrder,
        );
        expect(rows.map((p) => p.id), [p3.id, p1.id, p2.id]);
        expect(rows.map((p) => p.sortOrder), [0, 1, 2]);
        expect(rows.first.originalKey, p3.originalKey);
        expect(rows.first.editedKey, p3.editedKey);
        expect(rows.first.editVersion, 1);
        expect(rows.first.uploaderId, member);
        expect(events.single.kind, LiveKind.photo);
      },
    );

    // BR 81
    test(
      "Given published story, when an owner makes another member's photo "
      'the hero, then allowed; a plain member who did not upload it, or a '
      'photo of another story, then FORBIDDEN',
      () async {
        final owner = await fx.user();
        final uploader = await fx.user();
        final bystander = await fx.user();
        final (family, story) = await familyStory(
          owner,
          authorRole: MembershipRole.owner,
          members: [uploader, bystander],
        );
        final first = await fx.photo(story, uploaderId: owner);
        final theirs = await fx.photo(
          story,
          uploaderId: uploader,
          sortOrder: 1,
        );
        final elsewhere = await fx.photo(
          await fx.story(family, authorId: owner),
          uploaderId: owner,
        );

        await expectLater(
          endpoints.photo.setHero(
            asUser(sessionBuilder, bystander),
            story.id!,
            theirs.id!,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
        await expectLater(
          endpoints.photo.setHero(
            asUser(sessionBuilder, owner),
            story.id!,
            elsewhere.id!,
          ),
          throwsAppError(AppErrorCode.forbidden),
        );

        await endpoints.photo.setHero(
          asUser(sessionBuilder, owner),
          story.id!,
          theirs.id!,
        );
        final photos = await endpoints.photo.list(
          asUser(sessionBuilder, owner),
          story.id!,
        );
        expect(photos.map((p) => p.id), [theirs.id, first.id]);
      },
    );
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: compile error, `The method 'setHero' isn't defined`.

- [ ] **Step 3: Implement `setHero`**

```dart
  /// Makes [photoId] the hero: one transaction rewrites the story's
  /// `sortOrder` to 0..n-1 with it first, keeping the others' order.
  Future<void> setHero(
    Session session,
    UuidValue storyId,
    UuidValue photoId,
  ) async {
    final photo = await Photo.db.findById(session, photoId);
    final story = await Story.db.findById(session, storyId);
    if (photo == null ||
        story == null ||
        photo.storyId != storyId ||
        !await _canChange(session, story, photo)) {
      throw forbidden();
    }
    await session.db.transaction((t) async {
      await Story.db.findById(
        session,
        storyId,
        transaction: t,
        lockMode: LockMode.forNoKeyUpdate,
      );
      final rows = await Photo.db.find(
        session,
        where: (p) => p.storyId.equals(storyId),
        orderByList: _order,
        transaction: t,
      );
      final ordered = [
        ...rows.where((p) => p.id == photoId),
        ...rows.where((p) => p.id != photoId),
      ];
      final changed = [
        for (final (i, p) in ordered.indexed)
          if (p.sortOrder != i) p.copyWith(sortOrder: i),
      ];
      if (changed.isEmpty) return;
      await Photo.db.update(
        session,
        changed,
        columns: (p) => [p.sortOrder],
        transaction: t,
      );
    });
    await _postIfPublished(session, story, deleted: false);
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/photo_endpoint_test.dart`
Expected: 22 tests pass.

- [ ] **Step 5: Commit** (regenerate first: `mise exec -- just server-generate`)

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): PhotoEndpoint.setHero"
```

### Task 6: `MediaEndpoint` for photo keys

**Files:**
- Create: `apps/server/lib/src/endpoints/media_endpoint.dart`
- Create: `apps/server/test/integration/media_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

`apps/server/test/integration/media_endpoint_test.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/photo_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given MediaEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    Future<List<int>?> read(UuidValue user, String key) async {
      final data = await endpoints.media.get(asUser(sessionBuilder, user), key);
      return data == null ? null : bytesOf(data);
    }

    test('when an anonymous caller reads then unauthenticated', () async {
      await expectLater(
        endpoints.media.get(sessionBuilder, 'users/x/avatar/y.jpg'),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    // BR 90
    test(
      'Given draft edit, then author reads original and edited blobs; other '
      'member cannot read edited blob; tree reader reads published original',
      () async {
        final author = await fx.user();
        final other = await fx.user();
        final reader = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        await fx.join(family, other);
        final child = await fx.family(
          Tree(id: family.treeId),
          parentId: family.id,
        );
        await fx.join(child, reader);
        final draft = await fx.story(
          family,
          authorId: author,
          status: StoryStatus.draft,
        );
        final edited = await fx.photo(draft, uploaderId: author, edited: true);
        final published = await fx.photo(
          await fx.story(family, authorId: author),
          uploaderId: author,
        );

        expect(await read(author, edited.originalKey), bytesOf(jpegBytes()));
        expect(await read(author, edited.editedKey!), bytesOf(pngBytes()));
        expect(await read(other, edited.editedKey!), isNull);
        expect(await read(reader, edited.originalKey), isNull);
        expect(
          await read(reader, published.originalKey),
          bytesOf(jpegBytes()),
        );
      },
    );

    // BR 80
    test(
      'Given malformed or unknown keys, then get returns null without errors',
      () async {
        final user = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, user);
        for (final key in [
          '',
          '../etc/passwd',
          'families/${family.id}/x/y/original.jpg',
          'families/${family.id}/stories/not-a-uuid/photos/1/original.jpg',
          'families/${family.id}/stories/${const Uuid().v7()}/photos/'
              '${const Uuid().v7()}/original.jpg',
        ]) {
          expect(await read(user, key), isNull, reason: key);
        }
      },
    );

    // BR 80
    test(
      'Given tree reader, when getMany mixes readable, unreadable and unknown '
      'keys, then only the readable ones come back',
      () async {
        final author = await fx.user();
        final reader = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        final child = await fx.family(
          Tree(id: family.treeId),
          parentId: family.id,
        );
        await fx.join(child, reader);
        final visible = await fx.photo(
          await fx.story(family, authorId: author),
        );
        final hidden = await fx.photo(
          await fx.story(family, authorId: author, status: StoryStatus.draft),
        );

        final got = await endpoints.media.getMany(
          asUser(sessionBuilder, reader),
          [visible.originalKey, hidden.originalKey, 'families/x/../../y', ''],
        );

        expect(got.keys, [visible.originalKey]);
        expect(bytesOf(got[visible.originalKey]!), bytesOf(jpegBytes()));
      },
    );

    test(
      'when the row exists but its blob is missing then get returns null '
      'and getMany omits it',
      () async {
        final author = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        final photo = await fx.photo(await fx.story(family, authorId: author));
        await fx.s.storage.deleteFile(
          storageId: 'private',
          path: photo.originalKey,
        );

        expect(await read(author, photo.originalKey), isNull);
        expect(
          await endpoints.media.getMany(asUser(sessionBuilder, author), [
            photo.originalKey,
          ]),
          isEmpty,
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/media_endpoint_test.dart`
Expected: compile error, `The getter 'media' isn't defined for the type 'TestEndpoints'`.

- [ ] **Step 3: Implement `MediaEndpoint` with photo keys**

`apps/server/lib/src/endpoints/media_endpoint.dart`:

```dart
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../generated/protocol.dart';
import '../media/blob_keys.dart';

/// Authorized blob reads (endpoint-contract.md §2.0): every key is resolved
/// to the row that holds it and access is checked on that row. Nobody parses
/// keys. Unknown, unreadable and missing blobs all look the same: null from
/// [get], absent from [getMany].
class MediaEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<ByteData?> get(Session session, String key) async {
    final visible = await _MediaAccess(session).visible({key});
    return visible.isEmpty ? null : _retrieve(session, key);
  }

  Future<Map<String, ByteData>> getMany(
    Session session,
    List<String> keys,
  ) async {
    final visible = await _MediaAccess(session).visible(keys.toSet());
    final result = <String, ByteData>{};
    for (final key in visible) {
      final data = await _retrieve(session, key);
      if (data != null) result[key] = data;
    }
    return result;
  }

  Future<ByteData?> _retrieve(Session session, String key) async {
    try {
      return await session.storage.retrieveFile(
        storageId: blobStorageId,
        path: key,
      );
    } on CloudStorageFileNotFoundException {
      return null;
    }
  }
}

/// Which requested keys the caller may read, decided per holding row.
class _MediaAccess {
  _MediaAccess(this.session) : authz = Authz(session);

  final Session session;
  final Authz authz;

  Future<Set<String>> visible(Set<String> keys) async {
    if (keys.isEmpty || authz.userId == null) return {};
    return {...await _photoKeys(keys)};
  }

  /// Photo originals and edits: `canReadStory` of the photo's story.
  Future<List<String>> _photoKeys(Set<String> keys) async {
    final photos = await Photo.db.find(
      session,
      where: (t) => t.originalKey.inSet(keys) | t.editedKey.inSet(keys),
    );
    final readable = <UuidValue, bool>{};
    return [
      for (final photo in photos)
        if (readable[photo.storyId] ??= await _canReadStory(photo.storyId))
          for (final key in [photo.originalKey, photo.editedKey])
            if (key != null && keys.contains(key)) key,
    ];
  }

  Future<bool> _canReadStory(UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    return story != null && await authz.canReadStory(story);
  }
}
```

(`await` inside a collection-`if` is legal Dart in an `async` function.)

Then: `mise exec -- just server-generate`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/media_endpoint_test.dart`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): MediaEndpoint reads photo blobs by row access"
```

### Task 7: `MediaEndpoint` for covers, person avatars and user avatars

**Files:**
- Modify: `apps/server/lib/src/endpoints/media_endpoint.dart`
- Test: `apps/server/test/integration/media_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
    // BR 25
    test(
      'Given a family cover, member can read it; non-member cannot; member '
      'of soft-deleted family cannot',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final key = await fx.cover(family);

        expect(await read(member, key), bytesOf(jpegBytes()));
        expect(await read(await fx.user(), key), isNull);

        await fx.softDelete((await Family.db.findById(fx.s, family.id!))!);
        expect(await read(member, key), isNull);
      },
    );

    test(
      'Given a person avatar, a member of any live family in the tree reads '
      "it, also after the person's home family is soft-deleted; an outsider "
      'cannot',
      () async {
        final cousin = await fx.user();
        final tree = await fx.tree();
        final home = await fx.family(tree);
        final other = await fx.family(tree, name: 'Other');
        await fx.join(other, cousin);
        final key = await fx.personAvatar(await fx.person(home));

        expect(await read(cousin, key), bytesOf(jpegBytes()));
        expect(await read(await fx.user(), key), isNull);

        await fx.softDelete(home);
        expect(await read(cousin, key), bytesOf(jpegBytes()));
      },
    );

    test(
      'Given a user avatar, the user and a co-member of a live family read '
      'it; a stranger, or a co-member only through a soft-deleted family, '
      'cannot',
      () async {
        final owner = await fx.user();
        final coMember = await fx.user();
        final formerCoMember = await fx.user();
        final live = await fx.family(await fx.tree());
        await fx.join(live, owner);
        await fx.join(live, coMember);
        final deleted = await fx.family(
          await fx.tree(),
          deletedAt: DateTime.now().toUtc(),
        );
        await fx.join(deleted, owner);
        await fx.join(deleted, formerCoMember);
        final key = await fx.userAvatar(owner);

        expect(await read(owner, key), bytesOf(jpegBytes()));
        expect(await read(coMember, key), bytesOf(jpegBytes()));
        expect(await read(formerCoMember, key), isNull);
        expect(await read(await fx.user(), key), isNull);
      },
    );

    test(
      'when getMany asks for a cover, a person avatar and a user avatar '
      'then each is checked on its own row',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final cover = await fx.cover(family);
        final avatar = await fx.personAvatar(await fx.person(family));
        final mine = await fx.userAvatar(member);
        final strangers = await fx.userAvatar(await fx.user());

        final got = await endpoints.media.getMany(
          asUser(sessionBuilder, member),
          [cover, avatar, mine, strangers],
        );

        expect(got.keys.toSet(), {cover, avatar, mine});
      },
    );
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/media_endpoint_test.dart`
Expected: the four new tests fail (cover, avatars read as null).

- [ ] **Step 3: Implement the other key holders**

Replace `visible` and add the three lookups in `_MediaAccess`:

```dart
  Future<Set<String>> visible(Set<String> keys) async {
    if (keys.isEmpty || authz.userId == null) return {};
    return {
      ...await _photoKeys(keys),
      ...await _coverKeys(keys),
      ...await _personAvatarKeys(keys),
      ...await _userAvatarKeys(keys),
    };
  }

  /// Family covers: live member of that family (D6b: not while deleted).
  Future<List<String>> _coverKeys(Set<String> keys) async {
    final families = await Family.db.find(
      session,
      where: (t) => t.coverKey.inSet(keys),
    );
    return [
      for (final family in families)
        if (await authz.isLiveMember(family.id!)) family.coverKey!,
    ];
  }

  /// Person avatars: member of a live family in the person's tree (D8).
  Future<List<String>> _personAvatarKeys(Set<String> keys) async {
    final people = await Person.db.find(
      session,
      where: (t) => t.avatarKey.inSet(keys),
    );
    final readable = <UuidValue, bool>{};
    return [
      for (final person in people)
        if (readable[person.treeId] ??= await authz.isTreeMemberOf(
          person.treeId,
        ))
          person.avatarKey!,
    ];
  }

  /// User avatars: the user themself, or a co-member of a live family.
  Future<List<String>> _userAvatarKeys(Set<String> keys) async {
    final users = await AppUser.db.find(
      session,
      where: (t) => t.avatarKey.inSet(keys),
    );
    return [
      for (final user in users)
        if (user.authUserId == authz.userId ||
            await _sharesLiveFamily(user.authUserId))
          user.avatarKey!,
    ];
  }

  Set<UuidValue>? _myLiveFamilies;

  Future<bool> _sharesLiveFamily(UuidValue other) async {
    final mine = _myLiveFamilies ??= await _liveFamiliesOf(authz.userId!);
    if (mine.isEmpty) return false;
    final shared = await Membership.db.count(
      session,
      where: (t) => t.userId.equals(other) & t.familyId.inSet(mine),
    );
    return shared > 0;
  }

  Future<Set<UuidValue>> _liveFamiliesOf(UuidValue user) async {
    final memberships = await Membership.db.find(
      session,
      where: (t) => t.userId.equals(user),
    );
    if (memberships.isEmpty) return {};
    final live = await Family.db.find(
      session,
      where: (t) =>
          t.id.inSet(<UuidValue>{for (final m in memberships) m.familyId}) &
          t.deletedAt.equals(null),
    );
    return {for (final family in live) family.id!};
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/media_endpoint_test.dart`
Expected: 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server
git commit -m "feat(server): MediaEndpoint reads covers and avatars by row access"
```

### Task 8: Gate

- [ ] **Step 1: Format** — `mise exec -- dart format apps/server/lib apps/server/test`, then `mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test`. Expected: `Formatted N files (0 changed)`.
- [ ] **Step 2: Analyze** — `cd apps/server && mise exec -- dart analyze lib test` and `cd packages/tell_me_a_story_client && mise exec -- dart analyze`. Expected: `No issues found!` twice.
- [ ] **Step 3: Test** — `mise exec -- just server-test`. Expected: all pass (foundation 100 + 31 here).
- [ ] **Step 4: Commit** any format-only changes as `style(server): format 3d`; otherwise nothing to commit.

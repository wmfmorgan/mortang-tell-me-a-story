# Phase 3f: Live streams, purge, blob drain — implementation plan

> **For agentic workers:** execute task by task with superpowers:executing-plans. Each task: failing test, implementation, passing test, commit.

**Goal:** `LiveEndpoint.watchFamily`/`watchStory` authorized once at subscribe; the 60-day family purge (schema-design §4.3, D6c) and the `blob_deletions` drain as recurring future calls; both registered in `lib/server.dart` after `pod.start()`, cancelled first so a re-boot keeps one row per identifier.

**Architecture:** purge logic is a plain function (`purgeExpiredFamilies`) tested directly; the future call class is a thin wrapper over it and over the 3.0 `drainBlobDeletions`. Scheduling lives in `scheduleMaintenance(FutureCalls)` so a test can call it twice and count `serverpod_future_call` rows.

**Tech:** Serverpod 4.1.1 (`FutureCall` subclass → generated `lib/src/generated/future_calls.dart`, `pod.futureCalls.cancel/callRecurring(identifier:).cron()/.every()`), Dart 3.13.5.

**Spec:** Phase 3 index row 3f; schema-design §4.3; business-rules §7 cases 20, 21; D6b, D6c, D8.

## File map

| File | Role |
|---|---|
| `apps/server/lib/src/families/purge.dart` | `purgeExpiredFamilies(Session, {DateTime? now, PurgeFault? beforeDelete})` |
| `apps/server/lib/src/endpoints/live_endpoint.dart` | `LiveEndpoint.watchFamily`, `watchStory` |
| `apps/server/lib/src/future_calls/maintenance_future_call.dart` | `MaintenanceFutureCall.purgeFamilies`, `drainBlobs` |
| `apps/server/lib/src/future_calls/schedule.dart` | `scheduleMaintenance(FutureCalls)` (cancel, then register) |
| `apps/server/lib/server.dart` | calls `scheduleMaintenance(pod.futureCalls)` after `pod.start()` |
| `apps/server/test/integration/purge_test.dart` | BR 20, BR 21 |
| `apps/server/test/integration/live_endpoint_test.dart` | stream authorization |
| `apps/server/test/integration/schedule_test.dart` | two registrations → one row per identifier |
| generated: `endpoints.dart`, `future_calls.dart`, `serverpod.dart`, `protocol.yaml`, test tools, client `client.dart` | `just server-generate` |

Decisions taken here:
- "Last family in its tree" = no other family row (live or deleted) with the same `treeId`. Several expired families in one tree are purged one per transaction, oldest first; the last one takes the tree.
- Purge re-reads the family `FOR UPDATE` inside its transaction and skips it if it was recovered meanwhile. A failing family is logged and the loop continues; the next run retries it.
- `beforeDelete` is a test-only fault hook run after the keys are queued and before any delete, to prove fail-closed (BR 21).
- Stream refusal messages: family → `forbidden('member only')`; story (missing or unreadable) → default `forbidden()`, so ids don't leak.
- Schedule: purge `cron('0 3 * * *')` (UTC), drain `every(10 minutes)`; identifiers `purge-families`, `drain-blobs`.

## Task 1: purge function

- [ ] Write `test/integration/purge_test.dart`; run `cd apps/server && mise exec -- dart test test/integration/purge_test.dart` → fails (no `purge.dart`).

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/families/purge.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_outbox.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the 60-day family purge', (sessionBuilder, endpoints) {
    late Session s;
    late Fx fx;
    setUp(() {
      s = sessionBuilder.build();
      fx = Fx(s);
    });

    DateTime daysAgo(int days) =>
        DateTime.now().toUtc().subtract(Duration(days: days));

    String key(String name) => 'test/${const Uuid().v7()}/$name.jpg';

    Future<Set<String>> queued(Iterable<String> keys) async =>
        (await BlobDeletion.db.find(
          s,
          where: (t) => t.key.inSet(keys.toSet()),
        )).map((r) => r.key).toSet();

    /// A story with one photo (original + edited) in [family].
    Future<(String, String)> photoIn(Family family) async {
      final story = await fx.story(family);
      final original = key('original');
      final edited = key('edited');
      await Photo.db.insertRow(
        s,
        Photo(storyId: story.id!, originalKey: original, editedKey: edited),
      );
      return (original, edited);
    }

    Future<Family> setCover(Family family) =>
        Family.db.updateRow(s, family.copyWith(coverKey: key('cover')));

    Future<Person> setAvatar(Person person) =>
        Person.db.updateRow(s, person.copyWith(avatarKey: key('avatar')));

    // BR 20
    test(
      'when a family deleted 61 days ago with a child is purged then it is '
      'hard-deleted, the child parentId is null, its cover and photo keys are '
      'queued and its people move to the successor with their avatars',
      () async {
        final tree = await fx.tree();
        final grand = await fx.family(tree, name: 'Grand');
        final doomed = await setCover(
          await fx.family(tree, parentId: grand.id, deletedAt: daysAgo(61)),
        );
        final child = await fx.family(tree, parentId: doomed.id);
        final (original, edited) = await photoIn(doomed);
        final person = await setAvatar(await fx.person(doomed));

        await purgeExpiredFamilies(s);

        expect(await Family.db.findById(s, doomed.id!), isNull);
        expect((await Family.db.findById(s, child.id!))!.parentId, isNull);
        expect(await queued([doomed.coverKey!, original, edited]), {
          doomed.coverKey!,
          original,
          edited,
        });
        final moved = (await Person.db.findById(s, person.id!))!;
        expect(moved.homeFamilyId, grand.id);
        expect(moved.avatarKey, person.avatarKey);
        expect(await queued([person.avatarKey!]), isEmpty);
      },
    );

    // BR 20
    test('when the successor is picked then live families come before deleted '
        'ones, then the oldest', () async {
      final tree = await fx.tree();
      final doomed = await fx.family(tree, deletedAt: daysAgo(61));
      await fx.family(tree, name: 'Deleted', deletedAt: daysAgo(1));
      final live = await fx.family(tree, name: 'Live');
      final person = await fx.person(doomed);

      await purgeExpiredFamilies(s);

      expect((await Person.db.findById(s, person.id!))!.homeFamilyId, live.id);
    });

    // BR 20
    test(
      'when it was the last family in its tree then the tree, its people and '
      'places are deleted and the person-avatar keys are queued too',
      () async {
        final tree = await fx.tree();
        final doomed = await setCover(
          await fx.family(tree, deletedAt: daysAgo(61)),
        );
        final (original, edited) = await photoIn(doomed);
        final person = await setAvatar(await fx.person(doomed));
        final place = await fx.place(tree);

        await purgeExpiredFamilies(s);

        expect(await Family.db.findById(s, doomed.id!), isNull);
        expect(await Tree.db.findById(s, tree.id!), isNull);
        expect(await Person.db.findById(s, person.id!), isNull);
        expect(await Place.db.findById(s, place.id!), isNull);
        final keys = [doomed.coverKey!, original, edited, person.avatarKey!];
        expect(await queued(keys), keys.toSet());
      },
    );

    // BR 20
    test('when a family was deleted 59 days ago or is live then purge keeps '
        'it', () async {
      final tree = await fx.tree();
      final recent = await fx.family(tree, deletedAt: daysAgo(59));
      final live = await fx.family(tree);

      await purgeExpiredFamilies(s);

      expect(await Family.db.findById(s, recent.id!), isNotNull);
      expect(await Family.db.findById(s, live.id!), isNotNull);
    });

    // BR 21
    test('when the purge transaction fails then the family row remains and '
        'nothing is queued', () async {
      final tree = await fx.tree();
      final doomed = await setCover(
        await fx.family(tree, deletedAt: daysAgo(61)),
      );
      final (original, edited) = await photoIn(doomed);
      final person = await setAvatar(await fx.person(doomed));

      await purgeExpiredFamilies(
        s,
        beforeDelete: (family) async {
          if (family.id == doomed.id) throw StateError('purge failed');
        },
      );

      expect(await Family.db.findById(s, doomed.id!), isNotNull);
      expect(await Tree.db.findById(s, tree.id!), isNotNull);
      expect(await Person.db.findById(s, person.id!), isNotNull);
      expect(
        await queued([doomed.coverKey!, original, edited, person.avatarKey!]),
        isEmpty,
      );
    });

    // BR 21
    test('when the drain deleteFile fails then the blob_deletions row stays '
        'with attempts + 1', () async {
      final k = key('stuck');
      await queueBlobDeletions(s, [k]);

      await drainBlobDeletions(
        s,
        batchSize: 1000000,
        delete: (path) async {
          if (path == k) throw StateError('storage down');
        },
      );

      final rows = await BlobDeletion.db.find(s, where: (t) => t.key.equals(k));
      expect(rows.single.attempts, 1);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] Implement `lib/src/families/purge.dart`; rerun → 6 passing.

```dart
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../media/blob_outbox.dart';

/// How long a soft-deleted family stays recoverable.
const purgeAfter = Duration(days: 60);

/// Runs inside a purge transaction after the keys are queued and before any
/// row is deleted. Tests throw from it to prove the purge fails closed.
typedef PurgeFault = Future<void> Function(Family family);

/// Hard-deletes every family soft-deleted before `now - 60 days`, one
/// transaction per family (schema-design.md §4.3, D6c). Returns how many
/// families were purged. A family whose transaction fails is logged and
/// stays; nothing is queued for it, and the next run retries it.
Future<int> purgeExpiredFamilies(
  Session session, {
  DateTime? now,
  PurgeFault? beforeDelete,
}) async {
  final cutoff = (now ?? DateTime.now()).toUtc().subtract(purgeAfter);
  final doomed = await Family.db.find(
    session,
    where: (t) => t.deletedAt < cutoff,
    orderByList: (t) => [t.deletedAt.asc(), t.id.asc()],
  );
  var purged = 0;
  for (final candidate in doomed) {
    try {
      final done = await session.db.transaction(
        (t) => _purgeOne(session, candidate.id!, cutoff, t, beforeDelete),
      );
      if (done) purged++;
    } catch (e, stackTrace) {
      session.log(
        'family purge failed: ${candidate.id}',
        level: LogLevel.error,
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
  return purged;
}

Future<bool> _purgeOne(
  Session session,
  UuidValue familyId,
  DateTime cutoff,
  Transaction t,
  PurgeFault? beforeDelete,
) async {
  // Re-read under lock: a recover or an earlier purge may have won.
  final family = await Family.db.findById(
    session,
    familyId,
    transaction: t,
    lockMode: LockMode.forUpdate,
  );
  final deletedAt = family?.deletedAt;
  if (family == null || deletedAt == null || !deletedAt.isBefore(cutoff)) {
    return false;
  }

  final stories = await Story.db.find(
    session,
    where: (s) => s.familyId.equals(familyId),
    transaction: t,
  );
  final photos = stories.isEmpty
      ? const <Photo>[]
      : await Photo.db.find(
          session,
          where: (p) => p.storyId.inSet(stories.map((s) => s.id!).toSet()),
          transaction: t,
        );
  final keys = <String?>[
    family.coverKey,
    for (final photo in photos) ...[photo.originalKey, photo.editedKey],
  ];

  final others = await Family.db.find(
    session,
    where: (f) => f.treeId.equals(family.treeId) & f.id.notEquals(familyId),
    transaction: t,
  );

  if (others.isEmpty) {
    // Last family in its tree: the tree and its people go too.
    final people = await Person.db.find(
      session,
      where: (p) => p.treeId.equals(family.treeId),
      transaction: t,
    );
    keys.addAll(people.map((p) => p.avatarKey));
    await queueBlobDeletions(session, keys, transaction: t);
    await beforeDelete?.call(family);
    await Person.db.deleteWhere(
      session,
      where: (p) => p.treeId.equals(family.treeId),
      transaction: t,
    );
    await Family.db.deleteRow(session, family, transaction: t);
    await Tree.db.deleteWhere(
      session,
      where: (tr) => tr.id.equals(family.treeId),
      transaction: t,
    );
    return true;
  }

  // Successor: live before deleted, then oldest, then lowest id.
  others.sort((a, b) {
    final byDeleted = (a.deletedAt == null ? 0 : 1).compareTo(
      b.deletedAt == null ? 0 : 1,
    );
    if (byDeleted != 0) return byDeleted;
    final byCreated = a.createdAt.compareTo(b.createdAt);
    if (byCreated != 0) return byCreated;
    return a.id!.uuid.compareTo(b.id!.uuid);
  });
  final successor = others.first;
  await Person.db.updateWhere(
    session,
    columnValues: (p) => [p.homeFamilyId(successor.id!)],
    where: (p) => p.homeFamilyId.equals(familyId),
    transaction: t,
  );
  await queueBlobDeletions(session, keys, transaction: t);
  await beforeDelete?.call(family);
  await Family.db.deleteRow(session, family, transaction: t);
  return true;
}
```

- [ ] Commit `feat(server): 60-day family purge (schema-design §4.3, D6c)`.

## Task 2: LiveEndpoint

- [ ] Write `test/integration/live_endpoint_test.dart`; run → fails (`endpoints.live` undefined).

```dart
import 'dart:async';

import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given LiveEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    LiveEventDto event(Family family, {Story? story}) => LiveEventDto(
      familyId: family.id!,
      storyId: story?.id,
      kind: story == null ? LiveKind.story : LiveKind.note,
      deleted: false,
    );

    /// Subscribes, lets the listener register, posts [sent], returns the
    /// first event received.
    Future<LiveEventDto> receive(
      Stream<LiveEventDto> stream,
      LiveEventDto sent,
    ) async {
      final first = stream.first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await postLiveEvent(sessionBuilder.build(), sent);
      return first.timeout(const Duration(seconds: 5));
    }

    test('when a member watches the family then events arrive', () async {
      final member = await fx.user();
      final family = await fx.family(await fx.tree());
      await fx.join(family, member);
      final sent = event(family);

      final got = await receive(
        endpoints.live.watchFamily(asUser(sessionBuilder, member), family.id!),
        sent,
      );

      expect(got.familyId, family.id);
      expect(got.kind, sent.kind);
    });

    test('when a tree reader watches a family then events arrive', () async {
      final reader = await fx.user();
      final tree = await fx.tree();
      final parent = await fx.family(tree);
      final child = await fx.family(tree, parentId: parent.id);
      await fx.join(child, reader);

      final got = await receive(
        endpoints.live.watchFamily(asUser(sessionBuilder, reader), parent.id!),
        event(parent),
      );

      expect(got.familyId, parent.id);
    });

    test(
      'when a stranger watches a family then FORBIDDEN at subscribe',
      () async {
        final stranger = await fx.user();
        final family = await fx.family(await fx.tree());

        await expectLater(
          endpoints.live
              .watchFamily(asUser(sessionBuilder, stranger), family.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden, 'member only'),
        );
      },
    );

    test(
      'when a member watches a soft-deleted family then FORBIDDEN',
      () async {
        final member = await fx.user();
        final family = await fx.family(
          await fx.tree(),
          deletedAt: DateTime.now().toUtc(),
        );
        await fx.join(family, member, MembershipRole.owner);

        await expectLater(
          endpoints.live
              .watchFamily(asUser(sessionBuilder, member), family.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden, 'member only'),
        );
      },
    );

    test(
      'when a member watches a published story then its events arrive',
      () async {
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, member);
        final story = await fx.story(family);

        final got = await receive(
          endpoints.live.watchStory(asUser(sessionBuilder, member), story.id!),
          event(family, story: story),
        );

        expect(got.storyId, story.id);
      },
    );

    test(
      'when a stranger watches a story then FORBIDDEN at subscribe',
      () async {
        final stranger = await fx.user();
        final family = await fx.family(await fx.tree());
        final story = await fx.story(family);

        await expectLater(
          endpoints.live
              .watchStory(asUser(sessionBuilder, stranger), story.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test(
      'when a member watches another member\'s draft then FORBIDDEN',
      () async {
        final author = await fx.user();
        final member = await fx.user();
        final family = await fx.family(await fx.tree());
        await fx.join(family, author);
        await fx.join(family, member);
        final draft = await fx.story(
          family,
          authorId: author,
          status: StoryStatus.draft,
        );

        await expectLater(
          endpoints.live
              .watchStory(asUser(sessionBuilder, member), draft.id!)
              .first,
          throwsAppError(AppErrorCode.forbidden),
        );
      },
    );

    test('when an anonymous caller watches then unauthenticated', () async {
      final family = await fx.family(await fx.tree());

      await expectLater(
        endpoints.live.watchFamily(sessionBuilder, family.id!).first,
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] Implement, then `mise exec -- just server-generate`; rerun → 8 passing.

```dart
import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../live/live_events.dart';

/// Live change streams. Authorized once, at subscribe.
class LiveEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Events for [familyId]: live members and tree readers.
  Stream<LiveEventDto> watchFamily(Session session, UuidValue familyId) async* {
    final authz = Authz(session);
    if (!await authz.isLiveMember(familyId) &&
        !await authz.isTreeReadable(familyId)) {
      throw forbidden('member only');
    }
    yield* session.messages.createStream<LiveEventDto>(familyChannel(familyId));
  }

  /// Events for [storyId]: whoever may read the story (`canReadStory`).
  Stream<LiveEventDto> watchStory(Session session, UuidValue storyId) async* {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canReadStory(story)) {
      throw forbidden();
    }
    yield* session.messages.createStream<LiveEventDto>(storyChannel(storyId));
  }
}
```

- [ ] Commit with generated files: `feat(server): LiveEndpoint watchFamily/watchStory`.

## Task 3: future calls and boot registration

- [ ] Write `test/integration/schedule_test.dart`; run → fails (no `schedule.dart`). Removing the `cancel` lines makes it fail with two rows per identifier (checked).

```dart
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:tell_me_a_story_server/src/future_calls/schedule.dart';
import 'package:tell_me_a_story_server/src/generated/future_calls.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given the maintenance schedule', (sessionBuilder, endpoints) {
    test('when it is registered twice (two boots) then each identifier has '
        'one row', () async {
      final s = sessionBuilder.build();
      await scheduleMaintenance(FutureCalls());
      await scheduleMaintenance(FutureCalls());

      for (final id in [purgeFamiliesCallId, drainBlobsCallId]) {
        final rows = await FutureCallEntry.db.find(
          s,
          where: (t) => t.identifier.equals(id),
        );
        expect(rows, hasLength(1), reason: id);
      }
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] Implement the future call and the schedule, run `just server-generate`, wire `server.dart`; rerun → passing.

```dart
import 'package:serverpod/serverpod.dart';

import '../families/purge.dart';
import '../media/blob_outbox.dart';

/// Recurring maintenance jobs, scheduled in `server.dart` (slice 3f).
class MaintenanceFutureCall extends FutureCall {
  /// Hard-deletes families soft-deleted more than 60 days ago
  /// (schema-design.md §4.3, D6c).
  Future<void> purgeFamilies(Session session) async {
    await purgeExpiredFamilies(session);
  }

  /// Deletes queued blobs from storage (schema-design.md §4.3).
  Future<void> drainBlobs(Session session) async {
    await drainBlobDeletions(session);
  }
}
```

```dart
import '../generated/future_calls.dart';

/// Identifiers of the recurring maintenance calls in `serverpod_future_call`.
const purgeFamiliesCallId = 'purge-families';
const drainBlobsCallId = 'drain-blobs';

/// Schedules the purge (daily, 03:00 UTC) and the blob drain (every 10
/// minutes). Each identifier is cancelled first, so a re-boot replaces the
/// row instead of adding a second one. Call it after `pod.start()`.
Future<void> scheduleMaintenance(FutureCalls calls) async {
  await calls.cancel(purgeFamiliesCallId);
  await calls
      .callRecurring(identifier: purgeFamiliesCallId)
      .cron('0 3 * * *')
      .maintenance
      .purgeFamilies();
  await calls.cancel(drainBlobsCallId);
  await calls
      .callRecurring(identifier: drainBlobsCallId)
      .every(const Duration(minutes: 10))
      .maintenance
      .drainBlobs();
}
```

`lib/server.dart` (tail):

```dart
  await pod.start();
  await applyConstraints(pod);
  await scheduleMaintenance(pod.futureCalls);
```

- [ ] Commit with generated files: `feat(server): schedule purge and blob drain future calls`.

## Gate

- `mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test` → 0 changed
- `cd apps/server && mise exec -- dart analyze lib test`; `cd packages/tell_me_a_story_client && mise exec -- dart analyze` → no issues
- `mise exec -- just server-test` → all passing

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

    // BR 20
    test('when two expired families share a tree then one run deletes the '
        'tree, both families and all people and queues every key', () async {
      final tree = await fx.tree();
      final a = await setCover(await fx.family(tree, deletedAt: daysAgo(70)));
      final b = await setCover(await fx.family(tree, deletedAt: daysAgo(61)));
      final (aOriginal, aEdited) = await photoIn(a);
      final (bOriginal, bEdited) = await photoIn(b);
      final pa = await setAvatar(await fx.person(a));
      final pb = await setAvatar(await fx.person(b, name: 'Bo'));

      await purgeExpiredFamilies(s);

      expect(await Tree.db.findById(s, tree.id!), isNull);
      expect(await Family.db.findById(s, a.id!), isNull);
      expect(await Family.db.findById(s, b.id!), isNull);
      expect(await Person.db.findById(s, pa.id!), isNull);
      expect(await Person.db.findById(s, pb.id!), isNull);
      final keys = [
        a.coverKey!,
        b.coverKey!,
        aOriginal,
        aEdited,
        bOriginal,
        bEdited,
        pa.avatarKey!,
        pb.avatarKey!,
      ];
      expect(await queued(keys), keys.toSet());
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

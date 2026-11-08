import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/families_fixtures.dart';
import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given PlaceEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late UuidValue member, childMember, stranger;
    late Tree tree;
    late Family root, child;

    PlaceInputDto input(String label, {String? mapboxPlaceId}) => PlaceInputDto(
      label: label,
      address: '1 Main St',
      lat: 1.5,
      lng: 2.5,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: false,
    );

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      member = await fx.user();
      childMember = await fx.user();
      stranger = await fx.user();
      tree = await fx.tree();
      root = await fx.family(tree);
      child = await fx.childOf(root, owner: childMember);
      await fx.join(root, member);
      await fx.join(await fx.family(await fx.tree()), stranger);
    });

    test('when signed out then the call is rejected before the body', () async {
      await expectLater(
        endpoints.place.list(sessionBuilder, root.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    test(
      'when a member creates a place then every family in the tree lists it',
      () async {
        final created = await endpoints.place.create(
          asUser(sessionBuilder, member),
          root.id!,
          input('  Farm '),
        );
        expect(created.label, 'Farm');
        expect(created.treeId, root.treeId);
        expect(created.lastUsedAt, isNotNull);

        final fromChild = await endpoints.place.list(
          asUser(sessionBuilder, childMember),
          child.id!,
        );
        expect(fromChild.map((p) => p.id), [created.id]);
        expect(
          await endpoints.place.get(
            asUser(sessionBuilder, childMember),
            created.id,
          ),
          isNotNull,
        );
      },
    );

    test('when a stranger reads or writes then FORBIDDEN or null', () async {
      final place = await fx.place(tree);
      final session = asUser(sessionBuilder, stranger);
      await expectLater(
        endpoints.place.list(session, root.id!),
        throwsAppError(AppErrorCode.forbidden),
      );
      await expectLater(
        endpoints.place.create(session, root.id!, input('X')),
        throwsAppError(AppErrorCode.forbidden),
      );
      await expectLater(
        endpoints.place.setFavorite(session, place.id!, true),
        throwsAppError(AppErrorCode.forbidden),
      );
      await expectLater(
        endpoints.place.markUsed(session, place.id!),
        throwsAppError(AppErrorCode.forbidden),
      );
      expect(await endpoints.place.get(session, place.id!), isNull);
    });

    // BR 137 (place part)
    test(
      'when a member creates a place through a soft-deleted family then '
      'FORBIDDEN and nothing changes',
      () async {
        final gone = await fx.childOf(
          root,
          owner: member,
          name: 'Gone',
          deletedAt: DateTime.now().toUtc(),
        );
        final before = await Place.db.count(
          fx.s,
          where: (t) => t.treeId.equals(root.treeId),
        );
        await expectLater(
          endpoints.place.create(
            asUser(sessionBuilder, member),
            gone.id!,
            input('Nope'),
          ),
          throwsAppError(AppErrorCode.forbidden),
        );
        await expectLater(
          endpoints.place.list(asUser(sessionBuilder, member), gone.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
        expect(
          await Place.db.count(
            fx.s,
            where: (t) => t.treeId.equals(root.treeId),
          ),
          before,
        );
      },
    );

    test(
      'when a place with the same Mapbox id exists in the tree then create '
      'returns it and findByMapboxId finds it',
      () async {
        final session = asUser(sessionBuilder, member);
        final first = await endpoints.place.create(
          session,
          root.id!,
          input('Farm', mapboxPlaceId: 'mbx.1'),
        );
        final again = await endpoints.place.create(
          asUser(sessionBuilder, childMember),
          child.id!,
          input('Other label', mapboxPlaceId: 'mbx.1'),
        );
        expect(again.id, first.id);
        expect(again.label, 'Farm');
        final found = await endpoints.place.findByMapboxId(
          session,
          child.id!,
          'mbx.1',
        );
        expect(found?.id, first.id);
        expect(
          await endpoints.place.findByMapboxId(session, root.id!, 'mbx.2'),
          isNull,
        );
      },
    );

    test('when the label or address is blank then VALIDATION', () async {
      final session = asUser(sessionBuilder, member);
      await expectLater(
        endpoints.place.create(session, root.id!, input('  ')),
        throwsAppError(AppErrorCode.validation, 'label is required'),
      );
      await expectLater(
        endpoints.place.create(
          session,
          root.id!,
          PlaceInputDto(
            label: 'Farm',
            address: ' ',
            lat: 0,
            lng: 0,
            isFavorite: false,
          ),
        ),
        throwsAppError(AppErrorCode.validation, 'address is required'),
      );
    });

    test(
      'when marking used and favoriting then recents and favorites follow',
      () async {
        final session = asUser(sessionBuilder, member);
        final a = await fx.place(tree);
        final b = await fx.place(tree);

        await endpoints.place.markUsed(session, a.id!);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final usedB = await endpoints.place.markUsed(session, b.id!);
        expect(usedB.lastUsedAt, isNotNull);
        final fav = await endpoints.place.setFavorite(session, a.id!, true);
        expect(fav.isFavorite, isTrue);

        final recents = await endpoints.place.recents(
          session,
          root.id!,
          limit: 10,
        );
        expect(recents.map((p) => p.id), [b.id, a.id]);
        final limited = await endpoints.place.recents(
          session,
          root.id!,
          limit: 1,
        );
        expect(limited.map((p) => p.id), [b.id]);
        final favorites = await endpoints.place.favorites(session, root.id!);
        expect(favorites.map((p) => p.id), [a.id]);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

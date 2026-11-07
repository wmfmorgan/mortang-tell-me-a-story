import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'support/families_fixtures.dart';
import 'support/fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given ProfileEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    Future<AppUser> appUser(UuidValue user) async =>
        (await AppUser.db.findFirstRow(
          fx.s,
          where: (t) => t.authUserId.equals(user),
        ))!;

    test('when signed out then the call is rejected before the body', () async {
      await expectLater(
        endpoints.profile.me(sessionBuilder),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    // BR 109
    test(
      'when a signed-up account reads me then it gets its display name and '
      'its login email, read-only',
      () async {
        final email = uniqueEmail('ada');
        final user = await fx.userWithEmail(email, displayName: 'Ada');
        final me = await endpoints.profile.me(asUser(sessionBuilder, user));
        expect(me.authUserId, user);
        expect(me.displayName, 'Ada');
        expect(me.email, email);
        expect(me.birthVisibility, BirthVisibility.hidden);
      },
    );

    test('when the users row is missing then me creates it', () async {
      final user = await fx.user();
      await AppUser.db.deleteWhere(
        fx.s,
        where: (t) => t.authUserId.equals(user),
      );
      final me = await endpoints.profile.me(asUser(sessionBuilder, user));
      expect(me.authUserId, user);
      expect(me.email, isNull);
      expect(await appUser(user), isNotNull);
    });

    // BR 106
    test(
      'when the display name changes then every linked person in any tree '
      'takes it and unlinked people are untouched',
      () async {
        final user = await fx.user();
        final a = await fx.family(await fx.tree());
        final b = await fx.family(await fx.tree());
        final linkedA = await fx.person(a, userId: user, name: 'Old');
        final linkedB = await fx.person(b, userId: user, name: 'Old');
        final unlinked = await fx.person(a, name: 'Other');

        await endpoints.profile.saveName(
          asUser(sessionBuilder, user),
          '  New Name ',
        );

        expect((await appUser(user)).displayName, 'New Name');
        for (final p in [linkedA, linkedB]) {
          expect((await Person.db.findById(fx.s, p.id!))!.name, 'New Name');
        }
        expect((await Person.db.findById(fx.s, unlinked.id!))!.name, 'Other');
      },
    );

    // BR 107
    test(
      'when the display name is whitespace then no error and linked names '
      'keep their previous value',
      () async {
        final user = await fx.user();
        final home = await fx.family(await fx.tree());
        final linked = await fx.person(home, userId: user, name: 'Kept');

        await endpoints.profile.saveName(asUser(sessionBuilder, user), '   ');

        expect((await appUser(user)).displayName, isNull);
        expect((await Person.db.findById(fx.s, linked.id!))!.name, 'Kept');
      },
    );

    test(
      'when saving the account then name, birth (aligned to its precision), '
      'visibility and about are stored and linked names follow',
      () async {
        final user = await fx.user();
        final home = await fx.family(await fx.tree());
        final linked = await fx.person(home, userId: user, name: 'Old');

        await endpoints.profile.saveAccount(
          asUser(sessionBuilder, user),
          displayName: 'Grace',
          birthDate: DateTime.utc(1950, 6, 17),
          birthPrecision: DatePrecision.month,
          birthVisibility: BirthVisibility.year,
          about: ' Writer ',
        );

        final me = await endpoints.profile.me(asUser(sessionBuilder, user));
        expect(me.displayName, 'Grace');
        expect(me.birthDate, DateTime.utc(1950, 6));
        expect(me.birthPrecision, DatePrecision.month);
        expect(me.birthVisibility, BirthVisibility.year);
        expect(me.about, 'Writer');
        expect((await Person.db.findById(fx.s, linked.id!))!.name, 'Grace');

        await endpoints.profile.saveAccount(
          asUser(sessionBuilder, user),
          displayName: 'Grace',
        );
        final cleared = await endpoints.profile.me(
          asUser(sessionBuilder, user),
        );
        expect(cleared.birthDate, isNull);
        expect(cleared.birthPrecision, isNull);
        expect(cleared.birthVisibility, BirthVisibility.year);
        expect(cleared.about, isNull);
      },
    );

    test('when saving the account with bad input then VALIDATION', () async {
      final user = await fx.user();
      final session = asUser(sessionBuilder, user);
      await expectLater(
        endpoints.profile.saveAccount(
          session,
          displayName: 'A',
          birthDate: DateTime.utc(1950),
        ),
        throwsAppError(AppErrorCode.validation, 'birth precision is required'),
      );
      await expectLater(
        endpoints.profile.saveAccount(
          session,
          displayName: 'A',
          birthDate: DateTime.utc(999),
          birthPrecision: DatePrecision.year,
        ),
        throwsAppError(
          AppErrorCode.validation,
          'birth year must be four digits',
        ),
      );
      await expectLater(
        endpoints.profile.saveAccount(
          session,
          displayName: 'A',
          about: 'x' * 501,
        ),
        throwsAppError(
          AppErrorCode.validation,
          'about must be at most 500 characters',
        ),
      );
    });

    // BR 111
    test(
      'when saving an avatar then a fresh users/{uid}/avatar key is stored '
      'and the previous key is queued for deletion',
      () async {
        final user = await fx.user();
        final session = asUser(sessionBuilder, user);

        final first = await endpoints.profile.saveAvatar(
          session,
          byteData(jpegBytes),
        );
        expect(
          first,
          matches(RegExp('^users/${user.uuid}/avatar/[0-9a-f-]{36}\\.jpg\$')),
        );
        final second = await endpoints.profile.saveAvatar(
          session,
          byteData(jpegBytes),
        );

        expect(second, isNot(first));
        expect((await appUser(user)).avatarKey, second);
        expect(await fx.queuedBlobKeys(), contains(first));
        final stored = await fx.s.storage.retrieveFile(
          storageId: 'private',
          path: second,
        );
        expect(stored.lengthInBytes, jpegBytes.length);
      },
    );

    // BR 111
    test(
      'when the avatar is not a JPEG or too large then VALIDATION',
      () async {
        final user = await fx.user();
        final session = asUser(sessionBuilder, user);
        await expectLater(
          endpoints.profile.saveAvatar(session, byteData(pngBytes)),
          throwsAppError(AppErrorCode.validation, 'unsupported image type'),
        );
        await expectLater(
          endpoints.profile.saveAvatar(
            session,
            byteData([...jpegBytes, ...List.filled(2097152, 0)]),
          ),
          throwsAppError(AppErrorCode.validation, 'file is too large'),
        );
        expect((await appUser(user)).avatarKey, isNull);
      },
    );

    test(
      'when clearing the avatar then the key is queued and nulled',
      () async {
        final user = await fx.user();
        final session = asUser(sessionBuilder, user);
        final key = await endpoints.profile.saveAvatar(
          session,
          byteData(jpegBytes),
        );

        await endpoints.profile.clearAvatar(session);

        expect((await appUser(user)).avatarKey, isNull);
        expect(await fx.queuedBlobKeys(), contains(key));
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

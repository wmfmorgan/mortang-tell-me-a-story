import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/profile_repository.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _userId = '0190d7a0-0000-7000-8000-000000000001';

void main() {
  group('OwnProfile.fromDto', () {
    test('maps the account, its birth and the avatar key', () {
      final profile = OwnProfile.fromDto(
        server.OwnProfileDto(
          authUserId: server.UuidValue.fromString(_userId),
          displayName: 'Ada',
          email: 'ada@example.com',
          avatarKey: 'users/ada.jpg',
          birthDate: DateTime.utc(1990, 5),
          birthPrecision: server.DatePrecision.month,
          birthVisibility: server.BirthVisibility.yearMonth,
          about: 'Hi',
        ),
      );

      expect(profile.id, _userId);
      expect(profile.displayName, 'Ada');
      expect(profile.email, 'ada@example.com');
      expect(profile.avatarPath, 'users/ada.jpg');
      expect(profile.birthDate, DateTime(1990, 5));
      expect(profile.birthPrecision, 'month');
      expect(profile.birthVisibility, BirthVisibility.yearMonth);
      expect(profile.about, 'Hi');
    });

    test('leaves an empty account empty', () {
      final profile = OwnProfile.fromDto(
        server.OwnProfileDto(
          authUserId: server.UuidValue.fromString(_userId),
          birthVisibility: server.BirthVisibility.hidden,
        ),
      );

      expect(profile.displayName, isNull);
      expect(profile.email, isNull);
      expect(profile.avatarPath, isNull);
      expect(profile.birthDate, isNull);
      expect(profile.birthPrecision, isNull);
      expect(profile.birthVisibility, BirthVisibility.hidden);
    });
  });

  test('BirthVisibility maps to and from the server for every value', () {
    expect(BirthVisibility.values.map((v) => v.toServer()), [
      server.BirthVisibility.hidden,
      server.BirthVisibility.year,
      server.BirthVisibility.yearMonth,
      server.BirthVisibility.full,
    ]);
    for (final value in BirthVisibility.values) {
      expect(BirthVisibility.fromServer(value.toServer()), value);
    }
  });

  test('undecodable avatar bytes fail before any server call', () async {
    final api = ServerProfileRepository(
      client: server.Client('http://127.0.0.1:1/'),
    );

    expect(
      () => api.saveAvatar(Uint8List.fromList([1, 2, 3])),
      throwsArgumentError,
    );
  });
}

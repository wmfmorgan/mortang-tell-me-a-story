import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _personId = '0190d7a0-0000-7000-8000-000000000001';
const _familyId = '0190d7a0-0000-7000-8000-000000000002';
const _treeId = '0190d7a0-0000-7000-8000-000000000003';
const _userId = '0190d7a0-0000-7000-8000-000000000004';

server.UuidValue _uuid(String id) => server.UuidValue.fromString(id);

void main() {
  group('Person.fromDto', () {
    test('maps the home family, dates, picture key and link', () {
      final person = Person.fromDto(
        server.PersonDto(
          id: _uuid(_personId),
          treeId: _uuid(_treeId),
          homeFamilyId: _uuid(_familyId),
          name: 'Ada',
          email: 'ada@example.com',
          about: 'Loved gardens',
          avatarKey: 'people/avatar.jpg',
          userId: _uuid(_userId),
          passedAway: true,
          birthDate: DateTime.utc(1910, 3),
          birthPrecision: server.DatePrecision.month,
          deathDate: DateTime.utc(1990, 6, 2),
          deathPrecision: server.DatePrecision.day,
        ),
      );

      expect(person.id, _personId);
      expect(person.familyId, _familyId);
      expect(person.name, 'Ada');
      expect(person.email, 'ada@example.com');
      expect(person.about, 'Loved gardens');
      expect(person.avatarPath, 'people/avatar.jpg');
      expect(person.userId, _userId);
      expect(person.passedAway, isTrue);
      expect(person.birthDate, DateTime(1910, 3));
      expect(person.birthPrecision, 'month');
      expect(person.passingDate, DateTime(1990, 6, 2));
      expect(person.passingPrecision, 'day');
    });

    test('leaves optional fields null', () {
      final person = Person.fromDto(
        server.PersonDto(
          id: _uuid(_personId),
          treeId: _uuid(_treeId),
          homeFamilyId: _uuid(_familyId),
          name: 'Bob',
          passedAway: false,
        ),
      );

      expect(person.email, isNull);
      expect(person.userId, isNull);
      expect(person.avatarPath, isNull);
      expect(person.birthDate, isNull);
      expect(person.birthPrecision, isNull);
      expect(person.passingDate, isNull);
      expect(person.passingPrecision, isNull);
      expect(person.passedAway, isFalse);
    });
  });

  group('PersonProfile.fromDto', () {
    test('maps the profile dialog fields', () {
      final profile = PersonProfile.fromDto(
        server.PersonProfileDto(
          id: _uuid(_personId),
          homeFamilyId: _uuid(_familyId),
          name: 'Ada',
          isLinked: true,
          passedAway: true,
          birthDate: DateTime.utc(1910),
          birthPrecision: server.DatePrecision.year,
          deathDate: DateTime.utc(1990),
          deathPrecision: server.DatePrecision.year,
          about: 'Hi',
          avatarKey: 'users/a.jpg',
        ),
      );

      expect(profile.id, _personId);
      expect(profile.familyId, _familyId);
      expect(profile.name, 'Ada');
      expect(profile.isLinked, isTrue);
      expect(profile.passedAway, isTrue);
      expect(profile.birthDate, DateTime(1910));
      expect(profile.birthPrecision, 'year');
      expect(profile.passingDate, DateTime(1990));
      expect(profile.passingPrecision, 'year');
      expect(profile.about, 'Hi');
      expect(profile.avatarPath, 'users/a.jpg');
    });
  });

  group('ensureValidPersonCreate', () {
    test('accepts a non-empty name', () {
      expect(() => ensureValidPersonCreate(name: 'Ada'), returnsNormally);
    });

    test('rejects empty name', () {
      expect(
        () => ensureValidPersonCreate(name: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only name', () {
      expect(
        () => ensureValidPersonCreate(name: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects about longer than 500', () {
      expect(
        () => ensureValidPersonCreate(name: 'Ada', about: 'a' * 501),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

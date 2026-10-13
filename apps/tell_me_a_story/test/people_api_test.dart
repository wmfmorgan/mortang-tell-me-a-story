import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/people_api.dart';

void main() {
  group('Person.fromJson', () {
    test('parses required columns and optional email', () {
      final person = Person.fromJson({
        'id': 'p1',
        'family_id': 'f1',
        'name': 'Ada',
        'relationship': 'Grandmother',
        'email': 'ada@example.com',
        'created_by': 'u1',
      });

      expect(person.id, 'p1');
      expect(person.familyId, 'f1');
      expect(person.name, 'Ada');
      expect(person.relationship, 'Grandmother');
      expect(person.email, 'ada@example.com');
      expect(person.createdBy, 'u1');
    });

    test('allows null email', () {
      final person = Person.fromJson({
        'id': 'p2',
        'family_id': 'f1',
        'name': 'Bob',
        'relationship': 'Uncle',
        'email': null,
        'created_by': 'u1',
      });

      expect(person.email, isNull);
    });
  });

  group('personProfileFromRpc', () {
    test('reads the single row PostgREST returns for a table function', () {
      final profile = personProfileFromRpc([
        {
          'id': 'p1',
          'family_id': 'f1',
          'name': 'Ada',
          'birth_date': '1815-01-01',
          'birth_precision': 'year',
          'about': 'Wrote the notes.',
          'avatar_path': null,
          'passing_date': null,
          'passing_precision': null,
          'is_linked': false,
        },
      ]);

      expect(profile?.name, 'Ada');
      expect(profile?.birthDate?.year, 1815);
      expect(profile?.birthDate?.month, 1);
      expect(profile?.birthDate?.day, 1);
      expect(profile?.birthPrecision, 'year');
      expect(profile?.about, 'Wrote the notes.');
      expect(profile?.isLinked, isFalse);
    });

    test('reads a map and treats an empty list as missing', () {
      expect(
        personProfileFromRpc({
          'id': 'p1',
          'family_id': 'f1',
          'name': 'Ada',
          'is_linked': true,
        })?.isLinked,
        isTrue,
      );
      expect(personProfileFromRpc([]), isNull);
      expect(personProfileFromRpc(null), isNull);
    });
  });

  group('ensureValidPersonCreate', () {
    test('accepts a non-empty name', () {
      expect(
        () => ensureValidPersonCreate(name: 'Ada'),
        returnsNormally,
      );
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

  group('FakePeopleGateway', () {
    late FakePeopleGateway gateway;

    setUp(() {
      gateway = FakePeopleGateway(createdBy: 'u1');
    });

    test('createPerson rejects empty name before insert', () async {
      await expectLater(
        () => gateway.createPerson(familyId: 'f1', name: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(gateway.rows, isEmpty);
    });

    test('createPerson stores trimmed fields and createdBy', () async {
      final person = await gateway.createPerson(
        familyId: 'f1',
        name: '  Ada  ',
        email: '  ada@example.com  ',
      );

      expect(person.name, 'Ada');
      expect(person.relationship, isNull);
      expect(person.email, 'ada@example.com');
      expect(person.createdBy, 'u1');
      expect(person.familyId, 'f1');
    });

    test('createPerson omits blank email', () async {
      final person = await gateway.createPerson(
        familyId: 'f1',
        name: 'Ada',
        email: '   ',
      );

      expect(person.email, isNull);
    });

    test('listPeople returns people for family ordered by name', () async {
      await gateway.createPerson(
        familyId: 'f1',
        name: 'Zoe',
      );
      await gateway.createPerson(
        familyId: 'f1',
        name: 'Ada',
      );
      await gateway.createPerson(
        familyId: 'f2',
        name: 'Other',
      );

      final people = await gateway.listPeople('f1');
      expect(people.map((p) => p.name), ['Ada', 'Zoe']);
    });
  });
}

/// In-memory [PeopleGateway] that mirrors PeopleApi create validation rules.
class FakePeopleGateway extends PeopleGateway {
  FakePeopleGateway({required this.createdBy});

  final String createdBy;
  final List<Person> rows = [];
  var _seq = 0;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    final filtered = rows.where((p) => p.familyId == familyId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    DateTime? birthDate,
    String? birthPrecision,
    DateTime? passingDate,
    String? passingPrecision,
    String? about,
    String? email,
    List<int>? pictureBytes,
  }) async {
    ensureValidPersonCreate(name: name, about: about);
    final trimmedEmail =
        email != null && email.trim().isNotEmpty ? email.trim() : null;
    final person = Person(
      id: 'p${++_seq}',
      familyId: familyId,
      name: name.trim(),
      email: trimmedEmail,
      about: about,
      createdBy: createdBy,
    );
    rows.add(person);
    return person;
  }
}

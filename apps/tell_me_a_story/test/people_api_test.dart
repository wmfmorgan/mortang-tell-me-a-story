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

  group('ensureValidPersonCreate', () {
    test('accepts non-empty name and relationship', () {
      expect(
        () => ensureValidPersonCreate(
          name: 'Ada',
          relationship: 'Grandmother',
        ),
        returnsNormally,
      );
    });

    test('rejects empty name', () {
      expect(
        () => ensureValidPersonCreate(name: '', relationship: 'Aunt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only name', () {
      expect(
        () => ensureValidPersonCreate(name: '   ', relationship: 'Aunt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty relationship', () {
      expect(
        () => ensureValidPersonCreate(name: 'Ada', relationship: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only relationship', () {
      expect(
        () => ensureValidPersonCreate(name: 'Ada', relationship: '  '),
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
        () => gateway.createPerson(
          familyId: 'f1',
          name: '',
          relationship: 'Sister',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(gateway.rows, isEmpty);
    });

    test('createPerson rejects empty relationship before insert', () async {
      await expectLater(
        () => gateway.createPerson(
          familyId: 'f1',
          name: 'Ada',
          relationship: '  ',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(gateway.rows, isEmpty);
    });

    test('createPerson stores trimmed fields and createdBy', () async {
      final person = await gateway.createPerson(
        familyId: 'f1',
        name: '  Ada  ',
        relationship: ' Grandmother ',
        email: '  ada@example.com  ',
      );

      expect(person.name, 'Ada');
      expect(person.relationship, 'Grandmother');
      expect(person.email, 'ada@example.com');
      expect(person.createdBy, 'u1');
      expect(person.familyId, 'f1');
    });

    test('createPerson omits blank email', () async {
      final person = await gateway.createPerson(
        familyId: 'f1',
        name: 'Ada',
        relationship: 'Grandmother',
        email: '   ',
      );

      expect(person.email, isNull);
    });

    test('listPeople returns people for family ordered by name', () async {
      await gateway.createPerson(
        familyId: 'f1',
        name: 'Zoe',
        relationship: 'Cousin',
      );
      await gateway.createPerson(
        familyId: 'f1',
        name: 'Ada',
        relationship: 'Aunt',
      );
      await gateway.createPerson(
        familyId: 'f2',
        name: 'Other',
        relationship: 'Friend',
      );

      final people = await gateway.listPeople('f1');
      expect(people.map((p) => p.name), ['Ada', 'Zoe']);
    });
  });
}

/// In-memory [PeopleGateway] that mirrors PeopleApi create validation rules.
class FakePeopleGateway implements PeopleGateway {
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
    required String relationship,
    String? email,
  }) async {
    ensureValidPersonCreate(name: name, relationship: relationship);
    final trimmedEmail =
        email != null && email.trim().isNotEmpty ? email.trim() : null;
    final person = Person(
      id: 'p${++_seq}',
      familyId: familyId,
      name: name.trim(),
      relationship: relationship.trim(),
      email: trimmedEmail,
      createdBy: createdBy,
    );
    rows.add(person);
    return person;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
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

  test('_treeSelect keeps the same comma spacing as _rowSelect', () {
    final source = File('lib/data/people_api.dart').readAsStringSync();
    expect(
      source,
      contains(
        "static const _treeSelect = 'id, family_id, name, birth_date, passing_date';",
      ),
    );
    expect(
      source,
      contains("'id, family_id, name, relationship, email, created_by, '"),
    );
  });

  group('PeopleApi.listTreePeople', () {
    test(
      'listTreePeople reads dates from people for families in the tree',
      () async {
        final httpClient = _StubHttpClient(
          tree: [
            {'id': 'parent'},
            {'id': 'child'},
          ],
          people: [
            {
              'id': 'cousin',
              'family_id': 'child',
              'name': 'Cousin Ada',
              'birth_date': '1920-03-01',
              'passing_date': '1998-06-01',
            },
          ],
        );
        final api = PeopleApi(
          client: SupabaseClient(
            'http://localhost',
            'test-anon-key',
            httpClient: httpClient,
          ),
        );

        final people = await api.listTreePeople('parent');

        expect(people, hasLength(1));
        expect(people.single.name, 'Cousin Ada');
        expect(people.single.familyId, 'child');
        expect(people.single.birthDate, DateTime(1920, 3, 1));
        expect(people.single.passingDate, DateTime(1998, 6, 1));
        expect(httpClient.paths, [
          '/rest/v1/rpc/list_family_tree',
          '/rest/v1/people',
        ]);
        final peopleUrl = Uri.decodeFull(httpClient.peopleUrls.single)
            .replaceAll(' ', '');
        expect(
          peopleUrl,
          contains('select=id,family_id,name,birth_date,passing_date'),
        );
        expect(peopleUrl, contains('family_id=in.("parent","child")'));
        expect(people.single.familyId, isNot('outside'));
        expect(httpClient.paths, isNot(contains('/rest/v1/people_tree_read')));
      },
    );

    test('listTreePeople throws when list_family_tree is not a list', () async {
      final httpClient = _StubHttpClient(tree: {'id': 'parent'});
      final api = PeopleApi(
        client: SupabaseClient(
          'http://localhost',
          'test-anon-key',
          httpClient: httpClient,
        ),
      );

      await expectLater(
        api.listTreePeople('parent'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'listTreePeople falls back to the family when the tree is empty',
      () async {
        final httpClient = _StubHttpClient(
          tree: const [],
          people: [
            {
              'id': 'ada',
              'family_id': 'parent',
              'name': 'Ada',
              'birth_date': '1815-12-10',
              'passing_date': null,
            },
          ],
        );
        final api = PeopleApi(
          client: SupabaseClient(
            'http://localhost',
            'test-anon-key',
            httpClient: httpClient,
          ),
        );

        final people = await api.listTreePeople('parent');

        expect(people.single.name, 'Ada');
        expect(people.single.birthDate?.year, 1815);
        final peopleUrl = Uri.decodeFull(httpClient.peopleUrls.single)
            .replaceAll(' ', '');
        expect(peopleUrl, contains('family_id=in.("parent")'));
      },
    );
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
      await gateway.createPerson(familyId: 'f1', name: 'Zoe');
      await gateway.createPerson(familyId: 'f1', name: 'Ada');
      await gateway.createPerson(familyId: 'f2', name: 'Other');

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
    final trimmedEmail = email != null && email.trim().isNotEmpty
        ? email.trim()
        : null;
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

class _StubHttpClient extends http.BaseClient {
  _StubHttpClient({required this.tree, this.people = const []});

  final Object tree;
  final List<Map<String, dynamic>> people;
  final paths = <String>[];
  final peopleUrls = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    final Object body;
    if (request.url.path.endsWith('/rpc/list_family_tree')) {
      body = tree;
    } else if (request.url.path == '/rest/v1/people') {
      peopleUrls.add(request.url.toString());
      body = people;
    } else {
      body = const [];
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

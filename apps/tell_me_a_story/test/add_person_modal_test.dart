import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakePeopleGateway implements PeopleGateway {
  _FakePeopleGateway({List<Person>? seed}) : rows = [...?seed];

  final List<Person> rows;
  var _seq = 0;
  var createCalls = 0;

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
    createCalls++;
    ensureValidPersonCreate(name: name, relationship: relationship);
    final trimmedEmail = email != null && email.trim().isNotEmpty
        ? email.trim()
        : null;
    final person = Person(
      id: 'p${++_seq}',
      familyId: familyId,
      name: name.trim(),
      relationship: relationship.trim(),
      email: trimmedEmail,
      createdBy: 'u1',
    );
    rows.add(person);
    return person;
  }
}

Future<Person?> _openModal(
  WidgetTester tester, {
  required PeopleGateway api,
}) async {
  Person? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await AddPersonModal.show(
                context,
                familyId: _familyId,
                api: api,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows Add person chrome and choose/create modes', (
    tester,
  ) async {
    final api = _FakePeopleGateway();
    await _openModal(tester, api: api);

    expect(find.text('Add person'), findsOneWidget);
    expect(find.text('Choose or create'), findsOneWidget);
    expect(find.text('Choose existing'), findsOneWidget);
    expect(find.text('Create new'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('pick list shows people and returns selected person', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      seed: const [
        Person(
          id: 'p1',
          familyId: _familyId,
          name: 'Ada',
          relationship: 'Aunt',
          createdBy: 'u1',
        ),
        Person(
          id: 'p2',
          familyId: _familyId,
          name: 'Zoe',
          relationship: 'Cousin',
          createdBy: 'u1',
        ),
      ],
    );

    Person? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AddPersonModal.show(
                  context,
                  familyId: _familyId,
                  api: api,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Zoe'), findsOneWidget);
    expect(find.text('Aunt'), findsOneWidget);

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, 'p1');
    expect(result!.name, 'Ada');
    expect(find.text('Add person'), findsNothing);
  });

  testWidgets('create requires relationship', (tester) async {
    final api = _FakePeopleGateway();
    await _openModal(tester, api: api);

    await tester.tap(find.text('Create new'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Relationship'), findsOneWidget);
    expect(find.text('Email (optional)'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Ada Lovelace',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add person'), findsOneWidget);
    expect(find.text('Relationship is required'), findsOneWidget);
    expect(api.createCalls, 0);
  });

  testWidgets('create with name and relationship returns new person', (
    tester,
  ) async {
    final api = _FakePeopleGateway();

    Person? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AddPersonModal.show(
                  context,
                  familyId: _familyId,
                  api: api,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create new'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Ada Lovelace',
    );
    await tester.tap(find.text('Grandparent'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email (optional)'),
      'ada@example.com',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Ada Lovelace');
    expect(result!.relationship, 'Grandparent');
    expect(result!.email, 'ada@example.com');
    expect(api.createCalls, 1);
    expect(find.text('Add person'), findsNothing);
  });

  testWidgets('Cancel dismisses without returning a person', (tester) async {
    final api = _FakePeopleGateway(
      seed: const [
        Person(
          id: 'p1',
          familyId: _familyId,
          name: 'Ada',
          relationship: 'Aunt',
          createdBy: 'u1',
        ),
      ],
    );

    Person? result = const Person(
      id: 'sentinel',
      familyId: _familyId,
      name: 'Sentinel',
      relationship: 'X',
      createdBy: 'u1',
    );
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AddPersonModal.show(
                  context,
                  familyId: _familyId,
                  api: api,
                );
                completed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });
}

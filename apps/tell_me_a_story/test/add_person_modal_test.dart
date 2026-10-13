import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakePeopleGateway extends PeopleGateway {
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
    DateTime? birthDate,
    String? birthPrecision,
    DateTime? passingDate,
    String? passingPrecision,
    String? about,
    String? email,
    List<int>? pictureBytes,
  }) async {
    createCalls++;
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
      birthDate: birthDate,
      birthPrecision: birthPrecision,
      passingDate: passingDate,
      passingPrecision: passingPrecision,
      createdBy: 'u1',
    );
    rows.add(person);
    return person;
  }
}

Future<AddPersonResult?> _openModal(
  WidgetTester tester, {
  required PeopleGateway api,
}) async {
  AddPersonResult? result;
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
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the create form when Add person opens', (tester) async {
    final api = _FakePeopleGateway();
    await _openModal(tester, api: api);

    expect(find.text('Add person'), findsWidgets);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Upload picture'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add person'), findsOneWidget);
    expect(find.text('Choose existing'), findsNothing);
    expect(find.text('Create new person'), findsNothing);
    expect(find.text('Add to story'), findsNothing);
  });

  testWidgets('create form has profile labels and no relationship', (
    tester,
  ) async {
    final api = _FakePeopleGateway();
    await _openModal(tester, api: api);

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('DATE OF BIRTH'), findsOneWidget);
    expect(find.text('DATE OF PASSING'), findsOneWidget);
    expect(find.text('PICTURE'), findsOneWidget);
    expect(find.text('Upload picture'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(
      find.text('Email is hidden when Date of passing is set.'),
      findsOneWidget,
    );
    expect(find.text('May be left blank'), findsNothing);
    expect(find.text('(optional)'), findsNothing);
    expect(find.text('RELATIONSHIP'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add person'), findsOneWidget);
  });

  testWidgets('create with a name returns the new person', (tester) async {
    final api = _FakePeopleGateway();

    AddPersonResult? result;
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

    await tester.enterText(
      find.byKey(const Key('add-person-name')),
      'Ada Lovelace',
    );
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.person.name, 'Ada Lovelace');
    expect(result!.person.relationship, isNull);
    expect(result!.sendInvite, isFalse);
    expect(api.createCalls, 1);
    expect(find.text('Add person'), findsNothing);
  });

  testWidgets('about starts at two lines and the handle grows it', (
    tester,
  ) async {
    await _openModal(tester, api: _FakePeopleGateway());

    final aboutBox = find.byKey(const Key('add-person-about-box'));
    await tester.ensureVisible(aboutBox);
    final before = tester.getSize(aboutBox).height;
    expect(before, lessThan(90));
    await tester.drag(
      find.byKey(const Key('add-person-about-resize')),
      const Offset(0, 48),
    );
    await tester.pump();
    expect(tester.getSize(aboutBox).height, greaterThan(before + 20));
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

    AddPersonResult? result = const AddPersonResult(
      person: Person(
        id: 'sentinel',
        familyId: _familyId,
        name: 'Sentinel',
        relationship: 'X',
        createdBy: 'u1',
      ),
      sendInvite: false,
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

    final cancel = find.text('Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });
}

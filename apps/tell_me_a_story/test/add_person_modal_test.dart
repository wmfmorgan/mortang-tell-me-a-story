import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakePeopleGateway extends PeopleGateway {
  _FakePeopleGateway({
    List<Person>? seed,
    Map<String, Set<String>> tree = const {},
  }) : rows = [...?seed],
       _tree = tree;

  final List<Person> rows;
  final Map<String, Set<String>> _tree;
  var _seq = 0;
  var createCalls = 0;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    final filtered = rows.where((p) => p.familyId == familyId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Future<List<Person>> listTreePeople(String familyId) async {
    final ids = _tree[familyId] ?? {familyId};
    final filtered = rows.where((p) => ids.contains(p.familyId)).toList()
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

const _pickerKey = Key('add-person-picker');
const _searchKey = Key('add-person-search');
const _saveError = 'Couldn’t save person. Try again.';

class _ModalSession {
  AddPersonResult? result;
  var completed = false;
}

Person _dated({
  required String id,
  required String name,
  required int birthYear,
  int? passingYear,
}) {
  return Person(
    id: id,
    familyId: _familyId,
    name: name,
    birthDate: DateTime(birthYear, 1, 1),
    passingDate: passingYear == null ? null : DateTime(passingYear, 1, 1),
    createdBy: 'u1',
  );
}

Future<void> _openModal(
  WidgetTester tester, {
  required PeopleGateway api,
  String? storyId,
  Set<String> linkedPersonIds = const {},
  LinkStoryPerson? linkPerson,
  _ModalSession? session,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final picked = await AddPersonModal.show(
                context,
                familyId: _familyId,
                api: api,
                storyId: storyId,
                linkedPersonIds: linkedPersonIds,
                linkPerson: linkPerson,
              );
              final target = session;
              if (target == null) return;
              target.result = picked;
              target.completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Add person');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _openForm(
  WidgetTester tester, {
  required PeopleGateway api,
}) async {
  await _openModal(tester, api: api);
  await tester.tap(find.text('Create new person'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the create form after Create new person', (tester) async {
    final api = _FakePeopleGateway();
    await _openForm(tester, api: api);

    expect(find.text('Add person'), findsWidgets);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Upload picture'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add person'), findsOneWidget);
    expect(find.text('Choose existing'), findsNothing);
    expect(find.text('Add to story'), findsNothing);
  });

  testWidgets('create form has profile labels and no relationship', (
    tester,
  ) async {
    final api = _FakePeopleGateway();
    await _openForm(tester, api: api);

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
    final session = _ModalSession();
    await _openModal(tester, api: api, session: session);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('add-person-name')),
      'Ada Lovelace',
    );
    await _tapSave(tester);

    expect(session.result, isNotNull);
    expect(session.result!.person.name, 'Ada Lovelace');
    expect(session.result!.person.relationship, isNull);
    expect(session.result!.sendInvite, isFalse);
    expect(api.createCalls, 1);
    expect(find.text('Add person'), findsNothing);
  });

  testWidgets('about starts at two lines and the handle grows it', (
    tester,
  ) async {
    await _openForm(tester, api: _FakePeopleGateway());

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

    final session = _ModalSession();
    await _openModal(tester, api: api, session: session);

    final cancel = find.text('Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(session.completed, isTrue);
    expect(session.result, isNull);
  });

  testWidgets('Add person opens on the picker', (tester) async {
    await _openModal(tester, api: _FakePeopleGateway());

    expect(find.byKey(_pickerKey), findsOneWidget);
  });

  testWidgets('a person from another family in the tree shows their years', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      tree: {
        _familyId: {_familyId, 'other-family'},
      },
      seed: [
        Person(
          id: 'cousin',
          familyId: 'other-family',
          name: 'Cousin Ada',
          birthDate: DateTime(1920, 3, 1),
          passingDate: DateTime(1998, 6, 1),
          createdBy: 'u1',
        ),
        Person(
          id: 'outsider',
          familyId: 'outside-tree',
          name: 'Outside Bea',
          birthDate: DateTime(1910, 1, 1),
          passingDate: DateTime(1980, 1, 1),
          createdBy: 'u9',
        ),
      ],
    );
    await _openModal(tester, api: api);

    expect(find.text('Cousin Ada'), findsOneWidget);
    expect(find.text('1920-1998'), findsOneWidget);
    expect(find.text('Outside Bea'), findsNothing);
    expect(find.text('1910-1980'), findsNothing);
  });

  testWidgets('search lists tree people with their years', (tester) async {
    final api = _FakePeopleGateway(
      seed: [
        _dated(id: 'p2', name: 'Zoe', birthYear: 1990),
        _dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852),
      ],
    );
    await _openModal(tester, api: api);

    expect(find.text('Search people in this family'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('1815-1852'), findsOneWidget);
    expect(find.text('Zoe'), findsOneWidget);
    expect(find.text('1990'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ada')).dy,
      lessThan(tester.getTopLeft(find.text('Zoe')).dy),
    );

    await tester.enterText(_search, 'zoe');
    await tester.pump();

    expect(find.text('Zoe'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('people already linked to this story are left out', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      seed: [
        _dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852),
        _dated(id: 'p2', name: 'Zoe', birthYear: 1990),
      ],
    );
    await _openModal(tester, api: api, linkedPersonIds: const {'p1'});

    expect(find.text('Ada'), findsNothing);
    expect(find.text('1815-1852'), findsNothing);
    expect(find.text('Zoe'), findsOneWidget);

    await tester.enterText(_search, 'Ada');
    await tester.pump();

    expect(find.byKey(const Key('add-person-pick-p1')), findsNothing);
    expect(find.text('Create new person'), findsOneWidget);
  });

  testWidgets('tapping a name links that person and closes the modal', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      seed: [_dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852)],
    );
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: ({required String storyId, required String personId}) async {
        links.add((storyId: storyId, personId: personId));
      },
    );
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(links, [(storyId: 'story-1', personId: 'p1')]);
    expect(session.result, isNotNull);
    expect(session.result!.person.id, 'p1');
    expect(session.result!.sendInvite, isFalse);
    expect(find.byKey(_pickerKey), findsNothing);
  });

  testWidgets('Create new person is last and prefills the typed name', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      seed: [
        _dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852),
        _dated(id: 'p2', name: 'Zoe', birthYear: 1990),
      ],
    );
    await _openModal(tester, api: api);

    expect(find.text('Create new person'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Create new person')).dy,
      greaterThan(tester.getTopLeft(find.text('Zoe')).dy),
    );

    await tester.enterText(_search, 'Grace Hopper');
    await tester.pump();
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('add-person-name')))
          .controller!
          .text,
      'Grace Hopper',
    );
    expect(find.text('NAME'), findsOneWidget);
    expect(find.byKey(_pickerKey), findsNothing);
  });

  testWidgets('an empty tree shows only Create new person', (tester) async {
    await _openModal(tester, api: _FakePeopleGateway());

    expect(find.byKey(_pickerKey), findsOneWidget);
    expect(find.text('Create new person'), findsOneWidget);
    expect(find.text('NAME'), findsNothing);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('no matches shows only Create new person', (tester) async {
    final api = _FakePeopleGateway(
      seed: [_dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852)],
    );
    await _openModal(tester, api: api);
    await tester.enterText(_search, 'zzz');
    await tester.pump();

    expect(find.text('Ada'), findsNothing);
    expect(find.text('1815-1852'), findsNothing);
    expect(find.text('Create new person'), findsOneWidget);
    expect(find.byKey(_pickerKey), findsOneWidget);
  });

  testWidgets('an insert error shows the mapped message and stays open', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      seed: [_dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852)],
    );

    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: ({required String storyId, required String personId}) async {
        throw const PostgrestException(
          message: 'VALIDATION: Already on this story',
        );
      },
    );
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Already on this story'), findsOneWidget);
    expect(find.textContaining('VALIDATION:'), findsNothing);
    expect(find.byKey(const Key('add-person-error')), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(find.byKey(_pickerKey), findsOneWidget);
    expect(session.completed, isFalse);
    expect(session.result, isNull);
  });

  testWidgets('an unmapped error shows the save sentence in a snackbar', (
    tester,
  ) async {
    final api = _FakePeopleGateway(
      seed: [_dated(id: 'p1', name: 'Ada', birthYear: 1815, passingYear: 1852)],
    );
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: ({required String storyId, required String personId}) async {
        throw StateError('connection reset');
      },
    );
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SnackBar, _saveError), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.byKey(const Key('add-person-error')), findsNothing);
    expect(find.byKey(_pickerKey), findsOneWidget);
    expect(session.completed, isFalse);
  });

  testWidgets('a failed link after create retries the link only', (
    tester,
  ) async {
    final api = _FakePeopleGateway();
    var linkCalls = 0;
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: ({required String storyId, required String personId}) async {
        linkCalls++;
        if (linkCalls == 1) {
          throw const PostgrestException(
            message: 'VALIDATION: Already on this story',
          );
        }
      },
    );
    await tester.enterText(_search, 'Grace Hopper');
    await tester.pump();
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(api.createCalls, 1);
    expect(linkCalls, 1);
    expect(find.byKey(const Key('add-person-name')), findsOneWidget);
    expect(session.completed, isFalse);

    await _tapSave(tester);

    expect(api.createCalls, 1);
    expect(linkCalls, 2);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Already on this story'), findsOneWidget);
    expect(session.result, isNotNull);
    expect(session.result!.person.id, 'p1');
    expect(session.result!.person.name, 'Grace Hopper');
    expect(find.byKey(const Key('add-person-name')), findsNothing);
  });

  testWidgets('the picker list stays within 220', (tester) async {
    final api = _FakePeopleGateway(
      seed: [
        for (var i = 0; i < 30; i++)
          _dated(id: 'p$i', name: 'Person $i', birthYear: 1900 + i),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openModal(tester, api: api);

    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    expect(tester.getSize(list).height, lessThanOrEqualTo(220));
    expect(find.text('Create new person'), findsOneWidget);
  });

  testWidgets('creating a person links them through the same insert', (
    tester,
  ) async {
    final api = _FakePeopleGateway();
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: ({required String storyId, required String personId}) async {
        links.add((storyId: storyId, personId: personId));
      },
    );
    await tester.enterText(_search, 'Grace Hopper');
    await tester.pump();
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(api.createCalls, 1);
    expect(links, [(storyId: 'story-1', personId: 'p1')]);
    expect(session.result!.person.name, 'Grace Hopper');
    expect(find.byKey(_pickerKey), findsNothing);
  });
}

Finder get _search => find.byKey(_searchKey);

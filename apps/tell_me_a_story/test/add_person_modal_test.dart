import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakePeopleGateway extends PeopleGateway {
  _FakePeopleGateway({List<Person>? seed, this._tree = const {}})
    : rows = [...?seed];

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
    String? about,
    String? email,
    bool passedAway = false,
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
    expect(find.text('DATE OF BIRTH'), findsNothing);
    expect(find.text('DATE OF PASSING'), findsNothing);
    expect(find.text('Passed away'), findsOneWidget);
    expect(find.text('PICTURE'), findsOneWidget);
    expect(find.text('Upload picture'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(
      find.text('Email is hidden when Date of passing is set.'),
      findsNothing,
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
    expect(find.text('1920'), findsOneWidget);
    expect(find.text('1920-1998'), findsNothing);
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
    expect(find.text('1815'), findsOneWidget);
    expect(find.text('1815-1852'), findsNothing);
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

  testWidgets('one picked person then Add person links and closes', (
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
    await _tapSave(tester);

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
    await _tapSave(tester);

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
    await _tapSave(tester);

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

  testWidgets('form fields are disabled after create succeeds', (tester) async {
    final api = _FakePeopleGateway();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      linkPerson: ({required String storyId, required String personId}) async {
        throw const PostgrestException(message: 'VALIDATION: Already linked');
      },
    );
    await tester.enterText(_search, 'Grace Hopper');
    await tester.pump();
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(api.createCalls, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('add-person-name')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('add-person-about')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('add-person-email')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('add-person-picture')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('add-person-passed-away')))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add person'))
          .onPressed,
      isNotNull,
    );
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

  testWidgets('tapping a pill selects it and does not link', (tester) async {
    final api = _FakePeopleGateway(seed: _trio());
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: _record(links),
    );

    final pill = find.byKey(const Key('add-person-pick-a1'));
    await tester.tap(pill);
    await tester.pump();

    expect(links, isEmpty);
    expect(find.byKey(_pickerKey), findsOneWidget);
    expect(session.completed, isFalse);
    final material = tester.widget<Material>(
      find.ancestor(of: pill, matching: find.byType(Material)).first,
    );
    expect(material.color, albumSage.withValues(alpha: 0.18));
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, albumSage);
    expect(
      find.descendant(of: pill, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.descendant(of: pill, matching: find.text('A')), findsNothing);
  });

  testWidgets('tapping a selected pill clears it', (tester) async {
    final api = _FakePeopleGateway(seed: _trio());
    await _openModal(tester, api: api, storyId: 'story-1');

    final pill = find.byKey(const Key('add-person-pick-a1'));
    await tester.tap(pill);
    await tester.pump();
    await tester.tap(pill);
    await tester.pump();

    expect(
      find.descendant(of: pill, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    expect(find.descendant(of: pill, matching: find.text('A')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add person'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a selected pill is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await _openModal(tester, api: _FakePeopleGateway(seed: _trio()));

    final ada = find.byKey(const Key('add-person-pick-a1'));
    final grace = find.byKey(const Key('add-person-pick-a2'));
    await tester.tap(ada);
    await tester.pump();

    expect(tester.getSemantics(ada), isSemantics(isSelected: true));
    expect(tester.getSemantics(grace), isSemantics(isSelected: false));
    handle.dispose();
  });

  testWidgets('Add person is disabled until a pill is selected', (
    tester,
  ) async {
    await _openModal(tester, api: _FakePeopleGateway(seed: _trio()));

    final button = find.widgetWithText(FilledButton, 'Add person');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('selections survive search', (tester) async {
    final api = _FakePeopleGateway(seed: _trio());
    final links = <({String storyId, String personId})>[];
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      linkPerson: _record(links),
    );

    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();
    await tester.enterText(_search, 'Gr');
    await tester.pump();

    expect(find.text('Ada'), findsNothing);
    await tester.tap(find.byKey(const Key('add-person-pick-a2')));
    await tester.pump();
    await tester.enterText(_search, '');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('add-person-pick-a1')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('add-person-pick-a2')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await _tapSave(tester);

    expect(links, [
      (storyId: 'story-1', personId: 'a1'),
      (storyId: 'story-1', personId: 'a2'),
    ]);
  });

  testWidgets('Add person links every selected person one at a time', (
    tester,
  ) async {
    final api = _FakePeopleGateway(seed: _trio());
    final links = <({String storyId, String personId})>[];
    final gates = <Completer<void>>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: ({required String storyId, required String personId}) async {
        links.add((storyId: storyId, personId: personId));
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
      },
    );
    addTearDown(() {
      for (final gate in gates) {
        if (!gate.isCompleted) gate.complete();
      }
    });

    await tester.tap(find.byKey(const Key('add-person-pick-a3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-person-pick-a2')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
    await tester.pump();

    expect(links, hasLength(1));
    gates[0].complete();
    await tester.pump();
    expect(links, hasLength(2));
    gates[1].complete();
    await tester.pump();
    expect(links, hasLength(3));
    gates[2].complete();
    await tester.pumpAndSettle();

    expect(links, [
      (storyId: 'story-1', personId: 'a3'),
      (storyId: 'story-1', personId: 'a1'),
      (storyId: 'story-1', personId: 'a2'),
    ]);
    expect(session.result!.people.map((person) => person.id).toList(), [
      'a3',
      'a1',
      'a2',
    ]);
    expect(find.byKey(_pickerKey), findsNothing);
  });

  testWidgets('the button reads Adding… while saving', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await _openModal(
      tester,
      api: _FakePeopleGateway(seed: _trio()),
      storyId: 'story-1',
      linkPerson: ({required String storyId, required String personId}) {
        return gate.future;
      },
    );

    final pill = find.byKey(const Key('add-person-pick-a1'));
    await tester.tap(pill);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
    await tester.pump();

    expect(find.text('Adding…'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Close'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<InkWell>(pill).onTap, isNull);
  });

  testWidgets(
    'a partial failure keeps the failed selected and drops the saved',
    (tester) async {
      final api = _FakePeopleGateway(seed: _trio());
      final links = <({String storyId, String personId})>[];
      var graceAttempts = 0;
      final session = _ModalSession();
      await _openModal(
        tester,
        api: api,
        storyId: 'story-1',
        session: session,
        linkPerson:
            ({required String storyId, required String personId}) async {
              links.add((storyId: storyId, personId: personId));
              if (personId == 'a2') {
                graceAttempts++;
                if (graceAttempts == 1) {
                  throw const PostgrestException(
                    message: 'VALIDATION: Already on this story',
                  );
                }
              }
            },
      );

      await tester.tap(find.byKey(const Key('add-person-pick-a1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-person-pick-a2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-person-pick-a3')));
      await tester.pump();
      await _tapSave(tester);

      expect(links.map((link) => link.personId).toList(), ['a1', 'a2', 'a3']);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Already on this story'), findsOneWidget);
      expect(find.byKey(_pickerKey), findsOneWidget);
      expect(session.completed, isFalse);
      expect(find.text('Ada'), findsNothing);
      expect(find.text('Lin'), findsNothing);
      final grace = find.byKey(const Key('add-person-pick-a2'));
      expect(
        find.descendant(of: grace, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add person'),
            )
            .onPressed,
        isNotNull,
      );

      final before = links.length;
      await _tapSave(tester);

      expect(links.sublist(before), [(storyId: 'story-1', personId: 'a2')]);
      expect(session.result!.people.map((person) => person.id).toList(), [
        'a1',
        'a3',
        'a2',
      ]);
    },
  );

  testWidgets('X adds nobody', (tester) async {
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: _FakePeopleGateway(seed: _trio()),
      storyId: 'story-1',
      session: session,
      linkPerson: _record(links),
    );

    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(links, isEmpty);
    expect(session.completed, isTrue);
    expect(session.result, isNull);
  });

  testWidgets(
    'X after a partial failure returns only the people already saved',
    (tester) async {
      final links = <({String storyId, String personId})>[];
      final session = _ModalSession();
      await _openModal(
        tester,
        api: _FakePeopleGateway(seed: _trio()),
        storyId: 'story-1',
        session: session,
        linkPerson:
            ({required String storyId, required String personId}) async {
              links.add((storyId: storyId, personId: personId));
              if (personId == 'a2') {
                throw const PostgrestException(
                  message: 'VALIDATION: Already on this story',
                );
              }
            },
      );

      await tester.tap(find.byKey(const Key('add-person-pick-a1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-person-pick-a2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-person-pick-a3')));
      await tester.pump();
      await _tapSave(tester);

      final before = links.length;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(links, hasLength(before));
      expect(session.result!.people.map((person) => person.id).toList(), [
        'a1',
        'a3',
      ]);
    },
  );

  testWidgets('no cap', (tester) async {
    final people = [
      for (var i = 1; i <= 25; i++)
        _dated(
          id: 'n${i.toString().padLeft(2, '0')}',
          name: 'Member ${i.toString().padLeft(2, '0')}',
          birthYear: 1900 + i,
        ),
    ];
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openModal(
      tester,
      api: _FakePeopleGateway(seed: people),
      storyId: 'story-1',
      session: session,
      linkPerson: _record(links),
    );

    final listScroll = find.descendant(
      of: find.descendant(
        of: find.byKey(_pickerKey),
        matching: find.byType(ListView),
      ),
      matching: find.byType(Scrollable),
    );
    for (final person in people) {
      final row = find.byKey(Key('add-person-pick-${person.id}'));
      await tester.scrollUntilVisible(row, 80, scrollable: listScroll);
      await tester.tap(row);
      await tester.pump();
    }
    await _tapSave(tester);

    expect(links, hasLength(25));
    expect(session.result!.people, hasLength(25));
  });

  testWidgets('with no story id, picks return without a link', (tester) async {
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: _FakePeopleGateway(seed: _trio()),
      session: session,
      linkPerson: _record(links),
    );

    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-person-pick-a2')));
    await tester.pump();
    await _tapSave(tester);

    expect(links, isEmpty);
    expect(session.result!.people.map((person) => person.id).toList(), [
      'a1',
      'a2',
    ]);
  });

  testWidgets('Create new person links only the new person', (tester) async {
    final api = _FakePeopleGateway(seed: _trio());
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: api,
      storyId: 'story-1',
      session: session,
      linkPerson: _record(links),
    );

    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNothing);
    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ida');
    await _tapSave(tester);

    expect(api.createCalls, 1);
    expect(links, [(storyId: 'story-1', personId: 'p1')]);
    expect(session.result!.people.single.id, 'p1');
    expect(session.result!.sendInvite, isFalse);
  });

  testWidgets('Cancel adds nobody', (tester) async {
    final links = <({String storyId, String personId})>[];
    final session = _ModalSession();
    await _openModal(
      tester,
      api: _FakePeopleGateway(seed: _trio()),
      storyId: 'story-1',
      session: session,
      linkPerson: _record(links),
    );

    await tester.tap(find.byKey(const Key('add-person-pick-a1')));
    await tester.pump();
    final cancel = find.text('Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(links, isEmpty);
    expect(session.result, isNull);
  });
}

Finder get _search => find.byKey(_searchKey);

List<Person> _trio() {
  return [
    _dated(id: 'a1', name: 'Ada', birthYear: 1815),
    _dated(id: 'a2', name: 'Grace', birthYear: 1906),
    _dated(id: 'a3', name: 'Lin', birthYear: 1912),
  ];
}

LinkStoryPerson _record(List<({String storyId, String personId})> links) {
  return ({required String storyId, required String personId}) async {
    links.add((storyId: storyId, personId: personId));
  };
}

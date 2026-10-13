import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';
import 'package:tell_me_a_story/features/people/edit_person_dialog.dart';
import 'package:tell_me_a_story/features/people/person_profile_dialog.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';
const _helper =
    'Year is required. Add the month or day only if you remember. Day unlocks after Month.';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('add person saves a year and 500 characters of about', (
    tester,
  ) async {
    final api = _People();
    await _openAdd(tester, api);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Date of passing'), findsOneWidget);
    expect(find.text('Picture'), findsWidgets);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Relationship'), findsNothing);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(find.text(_helper), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ada');
    await tester.enterText(find.byKey(const Key('story-date-year')).first, '1987');
    await tester.pump();
    expect(find.text('Shows as: 1987'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('add-person-about')), 'a' * 500);
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(api.createCalls, 1);
    expect(api.lastBirth, DateTime(1987, 1, 1));
    expect(api.lastBirthPrecision, 'year');
    expect(api.lastAbout?.length, 500);
  });

  testWidgets('about of 501 does not call the API', (tester) async {
    final api = _People();
    await _openAdd(tester, api);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ada');
    await tester.enterText(find.byKey(const Key('add-person-about')), 'a' * 501);
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.createCalls, 0);
  });

  testWidgets('a passing date hides email and sends no invite', (tester) async {
    final api = _People();
    final invites = _Invites();
    await _openAdd(tester, api, invites: invites);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ada');
    await tester.enterText(find.byKey(const Key('story-date-year')).at(1), '1990');
    await tester.pump();
    expect(find.text('Email'), findsNothing);
    expect(find.text('Shows as: 1990'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.createCalls, 1);
    expect(api.lastEmail, isNull);
    expect(api.lastPassing, DateTime(1990, 1, 1));
    expect(invites.creates, 0);
    expect(invites.sent, isEmpty);
  });

  testWidgets('Not now saves the email and does not create an invite', (
    tester,
  ) async {
    final api = _People();
    final invites = _Invites();
    await _openAdd(tester, api, invites: invites);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ada');
    await tester.enterText(find.byKey(const Key('add-person-email')), 'ada@example.com');
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Send invite to Ada?'), findsOneWidget);
    expect(find.text('Send invite'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(api.lastEmail, 'ada@example.com');
    expect(invites.creates, 0);
  });

  testWidgets('Send invite saves, then create-invite, then send-invite-email', (
    tester,
  ) async {
    final api = _People();
    final invites = _Invites();
    await _openAdd(tester, api, invites: invites);
    await tester.tap(find.text('Create new person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ada');
    await tester.enterText(find.byKey(const Key('add-person-email')), 'ada@example.com');
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-invite-confirm-yes')));
    await tester.pumpAndSettle();

    expect(api.lastEmail, 'ada@example.com');
    expect(invites.personIds, ['p1']);
    expect(invites.emails, ['ada@example.com']);
    expect(invites.sent, ['i']);
  });

  testWidgets('a name pill opens a profile and hides edit when linked to someone else', (
    tester,
  ) async {
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: false,
        birthDate: null,
        about: 'Kin',
      );
    people.profile = PersonProfile(
      id: 'p1',
      familyId: _familyId,
      name: 'Ada',
      isLinked: false,
      birthDate: DateTime(1987, 1, 1),
      birthPrecision: 'year',
      passingDate: DateTime(1990, 1, 1),
      passingPrecision: 'year',
      about: 'Kin',
    );
    people.editor = Person(
      id: 'p1',
      familyId: _familyId,
      name: 'Ada',
      email: 'ada@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonNamePill(
            personId: 'p1',
            name: 'Ada',
            people: people,
            signedInUserId: 'me',
            child: const Text('Ada'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('person-pill-p1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('person-profile-dialog')), findsOneWidget);
    expect(find.text('Shows as 1987'), findsOneWidget);
    expect(find.text('Shows as 1990'), findsOneWidget);
    expect(find.text('Kin'), findsOneWidget);
    expect(find.text('ada@example.com'), findsNothing);
    expect(find.text('Relationship'), findsNothing);
    expect(find.text('Stories'), findsNothing);
    expect(find.byKey(const Key('person-avatar-empty')), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    people.profile = PersonProfile(
      id: 'p1',
      familyId: _familyId,
      name: 'Ada',
      isLinked: true,
    );
    people.editor = Person(
      id: 'p1',
      familyId: _familyId,
      name: 'Ada',
      userId: 'other',
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-pill-p1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('a missing profile shows the name only', (tester) async {
    final people = _People()..missing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPersonProfile(
                context,
                personId: 'p1',
                name: 'Pill Name',
                people: people,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pill Name'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('About'), findsNothing);
    expect(find.byKey(const Key('person-avatar-empty')), findsNothing);
    expect(find.byKey(const Key('person-avatar-image')), findsNothing);
  });

  testWidgets('edit writes an unlinked person and confirms a new email', (
    tester,
  ) async {
    final people = _People();
    final invites = _Invites();
    final person = Person(
      id: 'p1',
      familyId: _familyId,
      name: 'Ada',
      email: 'ada@example.com',
      about: 'Kin',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditPersonDialog(
              context,
              person: person,
              people: people,
              invites: invites,
              signedInUserId: 'me',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Picture'), findsWidgets);
    expect(find.text('ada@example.com'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('edit-person-name')), 'Ada Lovelace');
    await tester.enterText(find.byKey(const Key('edit-person-about')), 'Updated');
    await tester.enterText(
      find.byKey(const Key('edit-person-email')),
      'next@example.com',
    );
    final save = find.byKey(const Key('edit-person-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Send invite to Ada Lovelace?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(people.updatedName, 'Ada Lovelace');
    expect(people.updatedAbout, 'Updated');
    expect(people.updatedEmail, 'next@example.com');
    expect(people.wroteBirth, isTrue);
    expect(invites.creates, 0);
  });

  testWidgets('a linked self edits name and passing only', (tester) async {
    final people = _People();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditPersonDialog(
              context,
              person: Person(
                id: 'p1',
                familyId: _familyId,
                name: 'Ada',
                email: 'ada@example.com',
                userId: 'me',
              ),
              people: people,
              signedInUserId: 'me',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('About'), findsNothing);
    expect(find.text('Picture'), findsNothing);
    expect(find.text('ada@example.com'), findsOneWidget);
    final email = tester.widget<TextField>(find.byKey(const Key('edit-person-email')));
    expect(email.readOnly, isTrue);

    await tester.enterText(find.byKey(const Key('edit-person-name')), 'Ada Self');
    await tester.tap(find.byKey(const Key('edit-person-save')));
    await tester.pumpAndSettle();
    expect(people.updatedName, 'Ada Self');
    expect(people.wroteBirth, isFalse);
    expect(people.wroteAbout, isFalse);
    expect(people.wroteEmail, isFalse);
  });

  testWidgets('edit is absent when the person is linked to someone else', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showEditPersonDialog(
                context,
                person: const Person(
                  id: 'p1',
                  familyId: _familyId,
                  name: 'Ada',
                  userId: 'other',
                ),
                people: _People(),
                signedInUserId: 'me',
              );
              opened = result != null;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-person-dialog')), findsNothing);
    expect(opened, isFalse);
  });

  testWidgets('start-timeline member chips do not open a profile', (tester) async {
    final people = _People();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStartTimelineDialog(
              context,
              parentId: _familyId,
              parentName: 'Ada',
              stories: [
                Story(
                  id: 's1',
                  familyId: _familyId,
                  authorId: 'me',
                  timeframeStart: DateTime(1980, 1, 1),
                  status: StoryStatus.published,
                  people: const [(id: 'p1', name: 'Bea')],
                  personNames: const ['Bea'],
                ),
              ],
              familiesApi: _Families(),
              peopleApi: people,
              manageApi: _Manage(),
              currentUserId: 'me',
              origin: Story(
                id: 's1',
                familyId: _familyId,
                authorId: 'me',
                timeframeStart: DateTime(1980, 1, 1),
                status: StoryStatus.published,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-timeline-member-p1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-timeline-member-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-profile-dialog')), findsNothing);
  });
}

Future<void> _openAdd(
  WidgetTester tester,
  _People api, {
  InviteGateway? invites,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AddPersonModal.show(
              context,
              familyId: _familyId,
              api: api,
              invites: invites,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _People extends PeopleGateway {
  int createCalls = 0;
  DateTime? lastBirth;
  String? lastBirthPrecision;
  DateTime? lastPassing;
  String? lastAbout;
  String? lastEmail;
  String? updatedName;
  String? updatedAbout;
  String? updatedEmail;
  bool wroteBirth = false;
  bool wroteAbout = false;
  bool wroteEmail = false;
  PersonProfile? profile;
  Person? editor;
  var missing = false;
  String? signedPath;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    return const [Person(id: 'p1', familyId: _familyId, name: 'Bea')];
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
    createCalls++;
    lastBirth = birthDate;
    lastBirthPrecision = birthPrecision;
    lastPassing = passingDate;
    lastAbout = about;
    lastEmail = email != null && email.trim().isNotEmpty ? email.trim() : null;
    return Person(
      id: 'p1',
      familyId: familyId,
      name: name.trim(),
      email: lastEmail,
      birthDate: birthDate,
      birthPrecision: birthPrecision,
      passingDate: passingDate,
      passingPrecision: passingPrecision,
      about: about,
    );
  }

  @override
  Future<PersonProfile?> personProfile(String personId) async {
    if (missing) throw const PersonProfileNotFound();
    return profile;
  }

  @override
  Future<Person?> personForEdit(String personId) async => editor;

  @override
  Future<String?> signedPictureUrl({
    required String personId,
    String? path,
  }) async {
    signedPath = path;
    return null;
  }

  @override
  Future<Person> updatePerson({
    required String personId,
    required String name,
    DateTime? birthDate,
    String? birthPrecision,
    bool writeBirth = false,
    DateTime? passingDate,
    String? passingPrecision,
    bool writePassing = false,
    String? about,
    bool writeAbout = false,
    String? email,
    bool writeEmail = false,
    List<int>? pictureBytes,
  }) async {
    updatedName = name;
    updatedAbout = about;
    updatedEmail = email;
    wroteBirth = writeBirth;
    wroteAbout = writeAbout;
    wroteEmail = writeEmail;
    return Person(id: personId, familyId: _familyId, name: name, email: email);
  }
}

class _Invites implements InviteGateway {
  int creates = 0;
  final personIds = <String?>[];
  final emails = <String?>[];
  final sent = <String>[];

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => 'f';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    creates++;
    personIds.add(personId);
    emails.add(email);
    return const CreateInviteResult(
      inviteId: 'i',
      token: 't',
      expiresAt: '2099-01-01T00:00:00Z',
      inviteUrl: 'http://127.0.0.1:3000/invite/t',
    );
  }

  @override
  Future<String?> currentFamilyId() async => _familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {
    sent.add(inviteId);
  }
}

class _Families extends FamiliesGateway {
  @override
  Future<List<MemberFamily>> listMine() async => const [];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<FamilyPerson>> listMembers(String familyId) async {
    return const [
      FamilyPerson(userId: 'me', role: 'owner', displayName: 'Ada'),
    ];
  }
}

class _Manage implements ManageFamiliesGateway {
  @override
  Future<void> addCoOwner({required String familyId, required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> createRootFamily(String name) => throw UnimplementedError();

  @override
  Future<void> recoverFamily(String familyId) => throw UnimplementedError();

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember({required String familyId, required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> renameFamily({required String familyId, required String name}) {
    throw UnimplementedError();
  }

  @override
  Future<DateTime> resendInvite(String inviteId) => throw UnimplementedError();

  @override
  Future<void> revokeInvite(String inviteId) => throw UnimplementedError();

  @override
  Future<void> softDeleteFamily(String familyId) => throw UnimplementedError();

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) {
    throw UnimplementedError();
  }
}

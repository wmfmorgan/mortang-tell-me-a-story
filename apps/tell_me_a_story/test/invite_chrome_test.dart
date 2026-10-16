import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/config/env.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/invites/invite_modal.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

class _MemberOf extends FamiliesGateway {
  _MemberOf(this.id);

  final String id;

  @override
  Future<List<MemberFamily>> listMine() async {
    return [MemberFamily(id: id, name: 'Ada', createdAt: DateTime.utc(2020))];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}

class _StubInviteApi implements InviteGateway {
  int creates = 0;
  final emails = <String>[];
  final personIds = <String?>[];
  String? lastEmail;
  String? lastPersonId;
  Object? createError;
  Object? sendError;
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => 'family-1';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    creates += 1;
    lastEmail = email;
    lastPersonId = personId;
    personIds.add(personId);
    final error = createError;
    if (error != null) throw error;
    return CreateInviteResult(
      inviteId: 'i',
      token: 't',
      expiresAt: '2099-01-01T00:00:00Z',
      inviteUrl: 'http://127.0.0.1:3000/timeline?invite=t$creates',
    );
  }

  @override
  Future<String?> currentFamilyId() async => 'family-1';

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {
    final error = sendError;
    if (error != null) throw error;
    emails.add(inviteId);
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('INVITE_APP_ORIGIN defaults to local web port', () {
    expect(Env.inviteAppOrigin, 'http://127.0.0.1:3000');
  });

  testWidgets('timeline header shows Invite and New story', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimelinePage(
          api: _StubInviteApi(),
          familiesApi: _MemberOf('family-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Timeline'), findsWidgets);
    expect(find.text('Save draft'), findsNothing);
    expect(find.text('Publish'), findsNothing);
  });

  testWidgets('invite email screen sends the address and closes', (
    tester,
  ) async {
    final api = _StubInviteApi();
    await _open(tester, api);
    expect(find.text('Invite to the family archive'), findsOneWidget);
    expect(find.text('Any member can invite'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Text (SMS)'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Send invite'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('invite-email')), 'a@b.co');
    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.lastEmail, 'a@b.co');
    expect(api.emails, ['i']);
    expect(find.byType(InviteModal), findsNothing);
  });

  testWidgets('text invite is a placeholder and does not create an invite', (
    tester,
  ) async {
    final api = _StubInviteApi();
    await _open(tester, api);
    await tester.tap(find.byKey(const Key('invite-tab-sms')));
    await tester.pump();
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Send text invite'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-sms-send')));
    await tester.pump();
    expect(api.creates, 0);
    expect(find.text('Text invites are not available yet.'), findsOneWidget);
    expect(find.byType(InviteModal), findsOneWidget);
  });

  testWidgets('link screen copies the url and can generate another', (
    tester,
  ) async {
    final api = _StubInviteApi();
    await _open(tester, api);
    await tester.tap(find.byKey(const Key('invite-tab-link')));
    await tester.pump();
    expect(api.creates, 0);
    expect(find.text('Someone new'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-person-new')));
    await tester.pump();
    expect(find.text('Shareable invite link'), findsOneWidget);
    expect(find.textContaining('invite=t'), findsOneWidget);
    expect(api.lastPersonId, isNull);
    expect(
      find.text('Link expires in 7 days · Anyone can request to join'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Anyone with the link can request to join; a verified family member still confirms.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('invite-copy')));
    await tester.pump();
    expect(find.byType(InviteModal), findsOneWidget);

    final before = api.creates;
    await tester.tap(find.byKey(const Key('invite-generate')));
    await tester.pump();
    expect(api.creates, before + 1);

    await tester.ensureVisible(find.byKey(const Key('invite-done')));
    await tester.tap(find.byKey(const Key('invite-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(InviteModal), findsNothing);
  });

  testWidgets('link tab picks an unlinked person and does not open a profile', (
    tester,
  ) async {
    final api = _StubInviteApi();
    final people = _UnlinkedPeople();
    await _open(tester, api, people: people);

    expect(find.text('Someone new'), findsNothing);
    await tester.tap(find.byKey(const Key('invite-tab-link')));
    await tester.pump();

    expect(find.text('Ada'), findsWidgets);
    expect(find.text('Someone new'), findsOneWidget);
    expect(find.text('Passed'), findsNothing);
    expect(api.creates, 0);
    expect(find.byKey(const Key('person-profile-dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('invite-person-p1')));
    await tester.pump();
    expect(api.lastPersonId, 'p1');
    expect(api.lastEmail, isNull);
    expect(find.byKey(const Key('person-profile-dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('invite-person-new')));
    await tester.pump();
    expect(api.creates, 2);
    expect(api.lastPersonId, isNull);
    expect(api.personIds, ['p1', null]);
    expect(
      find.text('Link expires in 7 days · Anyone can request to join'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('invite-tab-email')));
    await tester.pump();
    expect(find.text('Someone new'), findsNothing);
  });

  testWidgets('email save stays and shows the error when create-invite fails', (
    tester,
  ) async {
    final api = _StubInviteApi()
      ..createError = InviteApiException(
        code: 'VALIDATION',
        message: 'person is already linked',
      );
    final people = _EmailPeople();
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _open(tester, api, people: people);

    expect(find.text('Not invited yet'), findsOneWidget);
    expect(find.text('No email yet'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('not-invited-add-p-kim')));
    await tester.tap(find.byKey(const Key('not-invited-add-p-kim')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('not-invited-email-p-kim')),
      'kim@test.local',
    );
    final save = find.byKey(const Key('not-invited-save-p-kim'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(people.updates, 1);
    expect(people.savedEmail, 'kim@test.local');
    expect(find.text('kim@test.local'), findsOneWidget);
    expect(find.text('No email yet'), findsNothing);
    expect(find.text('person is already linked'), findsOneWidget);
    expect(find.byKey(const Key('not-invited-row-p-kim')), findsOneWidget);
    expect(api.creates, 1);
    expect(api.emails, isEmpty);
  });

  testWidgets(
    'email save shows the mapped error when the person update fails',
    (tester) async {
      final api = _StubInviteApi();
      final people = _EmailPeople()
        ..updateError = const PostgrestException(
          message: 'VALIDATION: That email is already used',
          code: '23505',
        );
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, api, people: people);

      await tester.ensureVisible(
        find.byKey(const Key('not-invited-add-p-kim')),
      );
      await tester.tap(find.byKey(const Key('not-invited-add-p-kim')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('not-invited-email-p-kim')),
        'kim@test.local',
      );
      final save = find.byKey(const Key('not-invited-save-p-kim'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();

      expect(find.text('That email is already used'), findsOneWidget);
      expect(find.textContaining('VALIDATION:'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(api.creates, 0);
      expect(find.byKey(const Key('not-invited-row-p-kim')), findsOneWidget);
      expect(find.byKey(const Key('not-invited-email-p-kim')), findsOneWidget);
    },
  );

  testWidgets(
    'email save does not replace an unmapped person error with Try again',
    (tester) async {
      final api = _StubInviteApi();
      final people = _EmailPeople()
        ..updateError = const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        );
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, api, people: people);

      await tester.ensureVisible(
        find.byKey(const Key('not-invited-add-p-kim')),
      );
      await tester.tap(find.byKey(const Key('not-invited-add-p-kim')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('not-invited-email-p-kim')),
        'kim@test.local',
      );
      final save = find.byKey(const Key('not-invited-save-p-kim'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();

      expect(find.text('Try again'), findsNothing);
      expect(find.textContaining('duplicate key'), findsNothing);
      expect(api.creates, 0);
      expect(find.byKey(const Key('not-invited-email-p-kim')), findsOneWidget);
    },
  );

  testWidgets('invite on a saved email sends once and leaves the list', (
    tester,
  ) async {
    final api = _StubInviteApi();
    final people = _EmailPeople()
      ..person = const Person(
        id: 'p-baby',
        familyId: 'f',
        name: 'baby',
        email: 'baby@billy.com',
      );
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _open(tester, api, people: people);

    await tester.tap(find.byKey(const Key('not-invited-invite-p-baby')));
    await tester.pump();

    expect(api.creates, 1);
    expect(api.lastPersonId, 'p-baby');
    expect(api.lastEmail, 'baby@billy.com');
    expect(api.emails, ['i']);
    expect(find.byKey(const Key('not-invited-row-p-baby')), findsNothing);
    expect(find.text('Not invited yet'), findsNothing);
  });

  testWidgets('a failed send retries the email and does not create again', (
    tester,
  ) async {
    final api = _StubInviteApi()
      ..sendError = InviteApiException(
        code: 'VALIDATION',
        message: 'Invite has no email address to send to',
      );
    final people = _EmailPeople()
      ..person = const Person(
        id: 'p-baby',
        familyId: 'f',
        name: 'baby',
        email: 'baby@billy.com',
      );
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _open(tester, api, people: people);

    final invite = find.byKey(const Key('not-invited-invite-p-baby'));
    await tester.tap(invite);
    await tester.pump();
    expect(api.creates, 1);
    expect(api.emails, isEmpty);
    expect(find.text('Invite has no email address to send to'), findsOneWidget);

    api.sendError = null;
    await tester.tap(invite);
    await tester.pump();
    expect(api.creates, 1);
    expect(api.emails, ['i']);
    expect(find.byKey(const Key('not-invited-row-p-baby')), findsNothing);
  });
}

class _EmailPeople extends PeopleGateway {
  int updates = 0;
  String? savedEmail;
  Object? updateError;
  Person person = const Person(id: 'p-kim', familyId: 'f', name: 'Kim');

  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Person>> listUnlinkedPeople(String familyId) async => [person];

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
    bool clearPicture = false,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    updates += 1;
    savedEmail = email;
    person = Person(
      id: person.id,
      familyId: person.familyId,
      name: person.name,
      email: email,
    );
    return person;
  }
}

class _UnlinkedPeople extends PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Person>> listUnlinkedPeople(String familyId) async {
    return const [Person(id: 'p1', familyId: 'f', name: 'Ada')];
  }
}

Future<void> _open(
  WidgetTester tester,
  _StubInviteApi api, {
  PeopleGateway? people,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => InviteModal.show(
              context,
              familyId: '00000000-0000-0000-0000-000000000001',
              familyName: 'Ada',
              api: api,
              people: people,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

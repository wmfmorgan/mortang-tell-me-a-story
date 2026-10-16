import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/features/invites/invite_modal.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';
import 'package:tell_me_a_story/features/people/edit_person_dialog.dart';
import 'package:tell_me_a_story/features/people/person_profile_dialog.dart';
import 'package:tell_me_a_story/features/settings/settings_page.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Add person has no date fields and has the Passed away toggle', (
    tester,
  ) async {
    await _openAdd(tester, _People());
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('DATE OF BIRTH'), findsNothing);
    expect(find.text('Date of passing'), findsNothing);
    expect(find.text('DATE OF PASSING'), findsNothing);
    expect(find.text('Passed away'), findsOneWidget);
    expect(find.byKey(const Key('add-person-passed-away')), findsOneWidget);
    expect(
      find.text('Email is hidden when Date of passing is set.'),
      findsNothing,
    );
    expect(find.text('EMAIL'), findsOneWidget);
  });

  testWidgets('Edit person has no date fields and has the toggle', (
    tester,
  ) async {
    await _openEdit(
      tester,
      const Person(id: 'p1', familyId: _familyId, name: 'Rose Morgan'),
    );
    expect(find.text('Edit person'), findsOneWidget);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('Date of passing'), findsNothing);
    expect(find.text('Passed away'), findsOneWidget);
    expect(find.byKey(const Key('edit-person-passed-away')), findsOneWidget);
  });

  testWidgets('Edit person is hidden for a signed-in person', (tester) async {
    await _openEdit(
      tester,
      const Person(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        userId: 'member',
      ),
      signedInUserId: 'member',
    );
    expect(find.text('Edit person'), findsNothing);
    expect(find.text('Passed away'), findsNothing);
  });

  testWidgets('a plain member sees no action on a signed-in person', (
    tester,
  ) async {
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: true,
      )
      ..editor = const Person(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        userId: 'member',
      )
      ..steward = false;
    await _openProfile(tester, people, signedInUserId: 'plain');
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Family owners'), findsNothing);
    expect(find.text('Mark as passed away'), findsNothing);
    expect(find.text('Unmark passed away'), findsNothing);
  });

  testWidgets('an owner marks a signed-in member from Family owners', (
    tester,
  ) async {
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: true,
      )
      ..editor = const Person(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        userId: 'member',
      )
      ..steward = true;
    await _openProfile(tester, people, signedInUserId: 'owner');
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Family owners'), findsOneWidget);
    expect(find.text('Owner Controls'), findsNothing);
    expect(find.text('Mark as passed away'), findsOneWidget);
    expect(find.text('Unmark passed away'), findsNothing);

    await tester.tap(find.text('Mark as passed away'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as passed away?'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
    expect(find.text('Owner Controls'), findsNothing);

    await tester.tap(find.byKey(const Key('passed-away-confirm-yes')));
    await tester.pumpAndSettle();
    expect(people.marks, [(personId: 'p1', value: true)]);
  });

  testWidgets('an owner unmarks a flagged signed-in member', (tester) async {
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: true,
        passedAway: true,
      )
      ..editor = const Person(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        userId: 'member',
        passedAway: true,
      )
      ..steward = true;
    await _openProfile(tester, people, signedInUserId: 'owner');
    expect(find.text('Mark as passed away'), findsNothing);
    expect(find.text('Unmark passed away'), findsOneWidget);

    await tester.tap(find.text('Unmark passed away'));
    await tester.pumpAndSettle();
    expect(find.text('Unmark passed away?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('passed-away-confirm-yes')));
    await tester.pumpAndSettle();
    expect(people.marks, [(personId: 'p1', value: false)]);
  });

  testWidgets('Settings saves DOB and visibility, and Day waits for Month', (
    tester,
  ) async {
    final profile = _Profile();
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(profileApi: profile, inviteApi: _Invites()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Who can see it'), findsOneWidget);
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Year only'), findsOneWidget);
    expect(find.text('Year and month'), findsOneWidget);
    expect(find.text('Full date'), findsOneWidget);
    expect(find.text('Family Chronicler'), findsNothing);
    expect(find.textContaining('Helps pin'), findsNothing);
    expect(find.textContaining('JPG'), findsNothing);
    expect(find.textContaining('PNG'), findsNothing);
    expect(find.textContaining('Changes update'), findsNothing);
    expect(find.text('Remove'), findsNothing);

    final day = tester.widget<DropdownButton<int>>(
      find.byKey(const Key('story-date-day')),
    );
    expect(day.onChanged, isNull);

    await tester.enterText(find.byKey(const Key('story-date-year')), '1984');
    await tester.pump();
    expect(
      tester
          .widget<DropdownButton<int>>(find.byKey(const Key('story-date-day')))
          .onChanged,
      isNull,
    );

    await tester.tap(find.byKey(const Key('story-date-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('March').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(find.byKey(const Key('story-date-day')))
          .onChanged,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('settings-birth-visibility')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year only').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-save')));
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.births.single.$1, DateTime(1984, 3));
    expect(profile.births.single.$2, 'month');
    expect(profile.visibilities.single, 'year');
  });

  testWidgets('a saved photo does not offer Remove', (tester) async {
    final profile = _Profile(
      profile: OwnProfile(
        id: 'user-1',
        displayName: 'Sarah Morgan',
        email: 'sarah@example.com',
        avatarPath: 'user-1/avatar.jpg',
      ),
      download: _jpeg(),
    );
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(profileApi: profile, inviteApi: _Invites()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-avatar-image')), findsWidgets);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('picker rows show the birth year and no end year', (
    tester,
  ) async {
    final people = _People()
      ..tree = [
        Person(
          id: 'p1',
          familyId: _familyId,
          name: 'Ada',
          birthDate: DateTime(1815, 12, 10),
          passingDate: DateTime(1852, 11, 27),
        ),
      ];
    await _openPicker(tester, people);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('1815'), findsOneWidget);
    expect(find.text('1815-1852'), findsNothing);
    expect(find.textContaining('1852'), findsNothing);
  });

  testWidgets('a hidden birth date shows no year on the picker', (
    tester,
  ) async {
    final people = _People()
      ..tree = [
        const Person(id: 'p1', familyId: _familyId, name: 'Ada'),
      ];
    await _openPicker(tester, people);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.textContaining('1815'), findsNothing);
  });

  testWidgets('flagged people are absent from the picker and Not invited yet', (
    tester,
  ) async {
    final people = _People()
      ..tree = [
        const Person(id: 'p1', familyId: _familyId, name: 'Ada'),
        const Person(
          id: 'p2',
          familyId: _familyId,
          name: 'Pat',
          passedAway: true,
        ),
      ]
      ..unlinked = [
        const Person(
          id: 'p1',
          familyId: _familyId,
          name: 'Ada',
          email: 'ada@example.com',
        ),
        const Person(
          id: 'p2',
          familyId: _familyId,
          name: 'Pat',
          passedAway: true,
        ),
      ];
    await _openPicker(tester, people);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Pat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => InviteModal.show(
                context,
                familyId: _familyId,
                api: _Invites(),
                people: people,
              ),
              child: const Text('invite'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    expect(find.text('Not invited yet'), findsOneWidget);
    expect(find.text('Ada'), findsWidgets);
    expect(find.text('Pat'), findsNothing);

    await tester.tap(find.byKey(const Key('invite-tab-link')));
    await tester.pumpAndSettle();
    expect(find.text('Pat'), findsNothing);
    expect(find.byKey(const Key('invite-person-p2')), findsNothing);
  });
}

Future<void> _openAdd(WidgetTester tester, _People people) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => AddPersonModal.show(
            context,
            familyId: _familyId,
            api: people,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create new person'));
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester, _People people) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => AddPersonModal.show(
            context,
            familyId: _familyId,
            api: people,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openEdit(
  WidgetTester tester,
  Person person, {
  String? signedInUserId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showEditPersonDialog(
            context,
            person: person,
            people: _People(),
            signedInUserId: signedInUserId,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openProfile(
  WidgetTester tester,
  _People people, {
  required String signedInUserId,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPersonProfile(
            context,
            personId: 'p1',
            name: 'Ada',
            people: people,
            signedInUserId: signedInUserId,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _People extends PeopleGateway {
  List<Person> tree = const [];
  List<Person> unlinked = const [];
  PersonProfile? profile;
  Person? editor;
  var steward = false;
  final marks = <({String personId, bool value})>[];

  @override
  Future<List<Person>> listPeople(String familyId) async => tree;

  @override
  Future<List<Person>> listTreePeople(String familyId) async => tree;

  @override
  Future<List<Person>> listUnlinkedPeople(String familyId) async => unlinked;

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
    bool passedAway = false,
    List<int>? pictureBytes,
  }) async {
    return Person(id: 'new', familyId: familyId, name: name);
  }

  @override
  Future<PersonProfile?> personProfile(String personId) async => profile;

  @override
  Future<Person?> personForEdit(String personId) async => editor;

  @override
  Future<bool> isHomeFamilySteward(String familyId) async => steward;

  @override
  Future<void> markPassedAway({
    required String personId,
    required bool value,
  }) async {
    marks.add((personId: personId, value: value));
  }
}

class _Profile implements ProfileGateway {
  _Profile({
    this.profile = const OwnProfile(
      id: 'user-1',
      displayName: 'Sarah Morgan',
      email: 'sarah@example.com',
    ),
    this.download,
  });

  final OwnProfile profile;
  final Uint8List? download;
  final births = <(DateTime?, String?)>[];
  final visibilities = <String?>[];

  @override
  Future<Uint8List?> downloadAvatar(String path) async => download;

  @override
  Future<OwnProfile?> loadOwn() async => profile;

  @override
  Future<String> saveAvatar(Uint8List bytes) async => 'user-1/avatar.jpg';

  @override
  Future<void> clearAvatar() async {}

  @override
  Future<void> saveName(String displayName) async {}

  @override
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    String? birthVisibility,
    String? about,
  }) async {
    births.add((birthDate, birthPrecision));
    visibilities.add(birthVisibility);
  }

  @override
  Future<void> updateEmail(String email) async {}
}

class _Invites implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: _familyId, membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => _familyId;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
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
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

Uint8List _jpeg() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(180, 90, 40));
  return Uint8List.fromList(img.encodeJpg(image));
}

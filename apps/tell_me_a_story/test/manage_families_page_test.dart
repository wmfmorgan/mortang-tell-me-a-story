import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/features/family/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/manage_family_page.dart';

void main() {
  late _Directory directory;
  late _Manage manage;
  late GoRouter router;
  String? viewerId = 'me';

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
    viewerId = 'me';
    directory = _Directory();
    manage = _Manage(directory);
    router = GoRouter(
      initialLocation: AppRoutes.manageFamilies,
      routes: [
        GoRoute(
          path: AppRoutes.manageFamilies,
          builder: (context, state) =>
              ManageFamiliesPage(directoryApi: directory, manageApi: manage),
        ),
        GoRoute(
          path: AppRoutes.manageFamily,
          builder: (context, state) => ManageFamilyPage(
            familyId: state.pathParameters['familyId']!,
            directoryApi: directory,
            manageApi: manage,
            currentUserId: viewerId,
          ),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) =>
              const Scaffold(body: Text('timeline-landed')),
        ),
        GoRoute(
          path: AppRoutes.drafts,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: AppRoutes.newStory,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
    FamilySelection.clear();
  });

  Future<void> show(WidgetTester tester, {String? location}) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    if (location != null) router.go(location);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('hub lists active families and hides an empty recover section', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();

    expect(find.text('Manage families'), findsOneWidget);
    expect(find.text('North Archive'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('3 members · 2 stories'), findsOneWidget);
    expect(find.text('Recoverable (60 days)'), findsNothing);
    expect(find.textContaining('Available for recovery'), findsNothing);
  });

  testWidgets('recover shows the window and returns the family to active', (
    tester,
  ) async {
    directory.directory = FamilyDirectory(
      active: const [],
      recoverable: [
        FamilyRoster(
          id: 'old-1',
          name: 'West Archive',
          role: 'co_owner',
          memberCount: 1,
          publishedCount: 0,
          deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 4)),
        ),
      ],
    );

    await show(tester);

    expect(find.text('Recoverable (60 days)'), findsOneWidget);
    expect(find.textContaining('Available for recovery for'), findsOneWidget);
    expect(find.text('0 active'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manage-family-recover-old-1')));
    await tester.pumpAndSettle();

    expect(manage.recovered, ['old-1']);
    expect(find.text('Recoverable (60 days)'), findsNothing);
    expect(find.text('West Archive'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
  });

  testWidgets('Enter opens detail and does not remember the family', (
    tester,
  ) async {
    await show(tester);

    await tester.tap(find.byKey(const Key('manage-family-enter-fam-1')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/manage-families/fam-1');
    expect(FamilySelection.id, isNull);
    expect(find.byKey(const Key('manage-family-detail')), findsOneWidget);
  });

  testWidgets('Start a family remembers the new id and opens the timeline', (
    tester,
  ) async {
    await show(tester);

    await tester.tap(find.byKey(const Key('manage-families-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start-family-dialog')), findsOneWidget);
    expect(
      find.text('Create a new root family archive. You become the owner.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('start-family-create')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('start-family-name')),
      '  North Archive  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('start-family-create')));
    await tester.pumpAndSettle();

    expect(manage.createdNames, ['North Archive']);
    expect(FamilySelection.id, 'created-1');
    expect(router.state.uri.path, AppRoutes.timeline);
    expect(find.text('timeline-landed'), findsOneWidget);
  });

  testWidgets('owner sees make member and remove on co-owner rows', (
    tester,
  ) async {
    directory.detail = _detail(
      role: 'owner',
      people: const [
        FamilyPerson(userId: 'me', role: 'owner', displayName: 'Ada North'),
        FamilyPerson(
          userId: 'co-1',
          role: 'co_owner',
          displayName: 'Bea North',
        ),
        FamilyPerson(
          userId: 'co-2',
          role: 'co_owner',
          displayName: 'Cam North',
        ),
        FamilyPerson(
          userId: 'mem-1',
          role: 'member',
          displayName: 'Cara North',
        ),
      ],
    );
    await show(tester, location: '/manage-families/fam-1');

    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('manage-family-add-co-owner')), findsNothing);
    expect(
      find.byKey(const Key('manage-family-make-member-co-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('manage-family-remove-co-1')), findsOneWidget);
    expect(find.byKey(const Key('manage-family-make-member-me')), findsNothing);
    expect(find.byKey(const Key('manage-family-remove-me')), findsNothing);
    expect(find.byKey(const Key('manage-family-remove-mem-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('manage-family-make-member-co-1')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.text(
        'Make Bea North a member? They keep their stories and access but lose co-owner powers.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manage.demoted, isEmpty);

    await tester.tap(find.byKey(const Key('manage-family-make-member-co-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make member').last);
    await tester.pumpAndSettle();

    expect(manage.demoted, [(familyId: 'fam-1', userId: 'co-1')]);
    expect(manage.removed, isEmpty);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.byKey(const Key('manage-family-add-co-owner')), findsOneWidget);
  });

  testWidgets('co-owner sees no actions on co-owner or owner rows', (
    tester,
  ) async {
    viewerId = 'co-1';
    directory.detail = _detail(role: 'co_owner');
    await show(tester, location: '/manage-families/fam-1');

    expect(
      find.byKey(const Key('manage-family-make-member-co-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('manage-family-remove-co-1')), findsNothing);
    expect(find.byKey(const Key('manage-family-make-member-me')), findsNothing);
    expect(find.byKey(const Key('manage-family-remove-me')), findsNothing);
    expect(find.byKey(const Key('manage-family-remove-mem-1')), findsOneWidget);
  });

  testWidgets('remove on a co-owner row confirms before remove-member', (
    tester,
  ) async {
    directory.detail = _detail(role: 'owner');
    await show(tester, location: '/manage-families/fam-1');

    await tester.ensureVisible(
      find.byKey(const Key('manage-family-remove-co-1')),
    );
    await tester.tap(find.byKey(const Key('manage-family-remove-co-1')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Remove Bea North from North Archive?'), findsOneWidget);
    expect(
      find.text(
        'They lose access to North Archive and its branches. Their stories stay.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manage.removed, isEmpty);

    await tester.tap(find.byKey(const Key('manage-family-remove-co-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-member-confirm')));
    await tester.pumpAndSettle();

    expect(manage.removed, [(familyId: 'fam-1', userId: 'co-1')]);
    expect(manage.demoted, isEmpty);
  });

  testWidgets('remove on a member row confirms before remove-member', (
    tester,
  ) async {
    directory.detail = _detail(role: 'co_owner');
    await show(tester, location: '/manage-families/fam-1');

    await tester.ensureVisible(
      find.byKey(const Key('manage-family-remove-mem-1')),
    );
    await tester.tap(find.byKey(const Key('manage-family-remove-mem-1')));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Remove Cara North from North Archive?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manage.removed, isEmpty);

    await tester.tap(find.byKey(const Key('manage-family-remove-mem-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-member-confirm')));
    await tester.pumpAndSettle();
    expect(manage.removed, [(familyId: 'fam-1', userId: 'mem-1')]);
  });

  testWidgets('add co-owner cancel and close make no call', (tester) async {
    directory.detail = _detail(role: 'owner');
    await show(tester, location: '/manage-families/fam-1');

    Future<void> open() async {
      final button = find.byKey(const Key('manage-family-add-co-owner'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.byKey(const Key('add-co-owner-me')), findsNothing);
    expect(find.byKey(const Key('add-co-owner-co-1')), findsNothing);
    expect(find.byKey(const Key('add-co-owner-mem-1')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-co-owner-dialog')), findsNothing);
    expect(manage.added, isEmpty);

    await open();
    await tester.tap(find.byKey(const Key('add-co-owner-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-co-owner-dialog')), findsNothing);
    expect(manage.added, isEmpty);
  });

  testWidgets('pending invites stay hidden without rows or for a member', (
    tester,
  ) async {
    directory.detail = _detail(role: 'owner');
    await show(tester, location: '/manage-families/fam-1');
    expect(find.text('Pending Invites'), findsNothing);

    directory.detail = _detail(
      role: 'member',
      pendingInvites: [
        FamilyInvite(
          id: 'inv-1',
          email: 't.biggums@x.com',
          createdAt: DateTime(2026, 10, 8),
          expiresAt: DateTime(2026, 10, 15),
        ),
      ],
    );
    router.go(AppRoutes.manageFamilies);
    await tester.pumpAndSettle();
    router.go('/manage-families/fam-1');
    await tester.pumpAndSettle();
    expect(find.text('Pending Invites'), findsNothing);
    expect(find.text('t.biggums@x.com'), findsNothing);
  });

  testWidgets('pending invites resend and cancel', (tester) async {
    final sent = DateTime(2026, 10, 8);
    final expires = DateTime(2026, 10, 15);
    final expiredSent = DateTime(2020, 9, 20);
    final expiredOn = DateTime(2020, 9, 27);
    final created = DateTime(2026, 10, 9);
    final linkExpires = DateTime(2026, 10, 16);
    directory.detail = _detail(
      role: 'owner',
      pendingInvites: [
        FamilyInvite(
          id: 'inv-1',
          email: 'james.carter@gmail.com',
          createdAt: sent,
          expiresAt: expires,
        ),
        FamilyInvite(
          id: 'inv-2',
          email: 'pat.morgan@yahoo.com',
          createdAt: expiredSent,
          expiresAt: expiredOn,
        ),
        FamilyInvite(
          id: 'inv-3',
          email: null,
          createdAt: created,
          expiresAt: linkExpires,
        ),
      ],
    );
    await show(tester, location: '/manage-families/fam-1');

    expect(find.text('Pending Invites'), findsOneWidget);
    expect(find.text('3 waiting'), findsOneWidget);
    expect(find.text('james.carter@gmail.com'), findsOneWidget);
    expect(find.text('Invite link'), findsOneWidget);
    expect(
      find.text(
        'Sent ${albumMonthDay(sent)} · Expires ${albumMonthDay(expires)}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Sent ${albumMonthDay(expiredSent)} · Expired ${albumMonthDay(expiredOn)}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Created ${albumMonthDay(created)} · Expires ${albumMonthDay(linkExpires)}',
      ),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsNWidgets(2));
    expect(find.text('Expired'), findsOneWidget);
    expect(find.byKey(const Key('manage-family-resend-inv-1')), findsOneWidget);
    expect(find.byKey(const Key('manage-family-resend-inv-2')), findsOneWidget);
    expect(find.byKey(const Key('manage-family-resend-inv-3')), findsNothing);
    expect(
      find.text(
        'Resend emails the invite again and gives it 7 more days. Cancel stops the link from working.',
      ),
      findsOneWidget,
    );

    final gate = Completer<void>();
    manage.resendGate = gate;
    await tester.tap(find.byKey(const Key('manage-family-resend-inv-1')));
    await tester.pump();
    expect(
      find.byKey(const Key('manage-family-resend-busy-inv-1')),
      findsOneWidget,
    );
    expect(manage.resent, isEmpty);
    gate.complete();
    await tester.pumpAndSettle();
    expect(manage.resent, ['inv-1']);
    expect(
      find.text(
        'Invite sent again to james.carter@gmail.com. The old link no longer works.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('manage-family-cancel-invite-inv-3')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.text(
        "This invite link won't work for anyone anymore. You can make a new one any time.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cancel-invite-keep')));
    await tester.pumpAndSettle();
    expect(manage.revoked, isEmpty);

    await tester.tap(
      find.byKey(const Key('manage-family-cancel-invite-inv-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "james.carter@gmail.com won't be able to join North Archive with this link. You can invite them again any time.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cancel-invite-confirm')));
    await tester.pumpAndSettle();
    expect(manage.revoked, ['inv-1']);
  });

  testWidgets('a member does not see rename, transfer, or delete', (
    tester,
  ) async {
    directory.detail = _detail(role: 'member');
    await show(tester, location: '/manage-families/fam-1');

    expect(find.byKey(const Key('manage-family-detail')), findsOneWidget);
    expect(
      find.text(
        'Family members with access to read and contribute stories to the album.',
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('manage-family-rename')), findsNothing);
    expect(find.byKey(const Key('manage-family-add-co-owner')), findsNothing);
    expect(find.byKey(const Key('manage-family-transfer')), findsNothing);
    expect(find.byKey(const Key('manage-family-delete')), findsNothing);
    expect(find.byKey(const Key('manage-family-remove-co-1')), findsNothing);
    expect(find.byKey(const Key('manage-family-remove-mem-1')), findsNothing);
  });

  testWidgets('a co-owner can rename and remove a member only', (tester) async {
    directory.detail = _detail(role: 'co_owner');
    await show(tester, location: '/manage-families/fam-1');

    expect(find.byKey(const Key('manage-family-detail')), findsOneWidget);
    expect(
      find.text('Co-owners have the same powers as the owner.'),
      findsWidgets,
    );
    expect(find.byKey(const Key('manage-family-rename')), findsOneWidget);
    expect(find.byKey(const Key('manage-family-remove-mem-1')), findsOneWidget);
    expect(find.byKey(const Key('manage-family-remove-co-1')), findsNothing);
    expect(find.byKey(const Key('manage-family-transfer')), findsNothing);
    expect(find.byKey(const Key('manage-family-delete')), findsNothing);
    expect(find.text('Delete family…'), findsNothing);
  });

  testWidgets('add co-owner confirms the selected member', (tester) async {
    directory.detail = _detail(role: 'owner');
    await show(tester, location: '/manage-families/fam-1');

    final open = find.byKey(const Key('manage-family-add-co-owner'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-co-owner-dialog')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Add a co-owner'), findsOneWidget);
    expect(
      find.text(
        'Co-owners have the same powers as you. North Archive can have up to two.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 OF 2 CO-OWNER SPOTS USED'), findsOneWidget);
    expect(find.text('Search members'), findsOneWidget);
    expect(
      find.text(
        'Only people already in this family can be co-owners. To add someone new, invite them first.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-co-owner-mem-1')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('add-co-owner-submit')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('add-co-owner-search')),
      'nobody',
    );
    await tester.pump();
    expect(find.byKey(const Key('add-co-owner-mem-1')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('add-co-owner-search')),
      'cara',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-co-owner-mem-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-co-owner-submit')));
    await tester.pumpAndSettle();

    expect(manage.added, [(familyId: 'fam-1', userId: 'mem-1')]);
    expect(find.byKey(const Key('add-co-owner-dialog')), findsNothing);
  });

  testWidgets('transfer stays disabled until both choices are set', (
    tester,
  ) async {
    directory.detail = _detail(role: 'owner');
    await show(tester, location: '/manage-families/fam-1');

    expect(find.byKey(const Key('manage-family-detail')), findsOneWidget);
    expect(find.byKey(const Key('manage-family-delete')), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage-family-transfer')));
    await tester.pumpAndSettle();

    expect(find.text('Transfer ownership'), findsWidgets);
    expect(find.textContaining('confirm acceptance'), findsNothing);
    expect(find.textContaining('Added'), findsNothing);
    final submit = find.byKey(const Key('transfer-ownership-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('transfer-owner-co-1')));
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('transfer-become-member')));
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(manage.transfers, [
      (familyId: 'fam-1', newOwner: 'co-1', former: 'member'),
    ]);
  });

  testWidgets('delete confirms only when the typed name matches', (
    tester,
  ) async {
    directory.detail = _detail(role: 'owner');
    FamilySelection.remember('fam-1');
    await show(tester, location: '/manage-families/fam-1');

    await tester.tap(find.byKey(const Key('manage-family-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete North Archive?'), findsOneWidget);
    expect(
      find.text(
        'Hidden for 60 days, then permanently removed. Owner/co-owner can Recover from Manage families. Story tags stay if people are tagged elsewhere.',
      ),
      findsOneWidget,
    );
    final submit = find.byKey(const Key('delete-family-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete-family-confirm')),
      'North',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete-family-confirm')),
      '  North Archive  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(manage.deleted, ['fam-1']);
    expect(FamilySelection.id, isNull);
    expect(router.state.uri.path, AppRoutes.manageFamilies);
  });
}

FamilyDetail _detail({
  required String role,
  List<FamilyInvite> pendingInvites = const [],
  List<FamilyPerson>? people,
}) {
  return FamilyDetail(
    id: 'fam-1',
    name: 'North Archive',
    myRole: role,
    people:
        people ??
        const [
          FamilyPerson(userId: 'me', role: 'owner', displayName: 'Ada North'),
          FamilyPerson(
            userId: 'co-1',
            role: 'co_owner',
            displayName: 'Bea North',
          ),
          FamilyPerson(
            userId: 'mem-1',
            role: 'member',
            displayName: 'Cara North',
          ),
        ],
    pendingInvites: pendingInvites,
  );
}

class _Directory implements FamilyDirectoryGateway {
  FamilyDirectory directory = const FamilyDirectory(
    active: [
      FamilyRoster(
        id: 'fam-1',
        name: 'North Archive',
        role: 'owner',
        memberCount: 3,
        publishedCount: 2,
      ),
    ],
    recoverable: [],
  );

  FamilyDetail? detail = _detail(role: 'owner');

  @override
  Future<FamilyDirectory> listDirectory() async => directory;

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async => detail;
}

class _Manage implements ManageFamiliesGateway {
  _Manage(this.directory);

  final _Directory directory;
  final createdNames = <String>[];
  final recovered = <String>[];
  final deleted = <String>[];
  final added = <({String familyId, String userId})>[];
  final demoted = <({String familyId, String userId})>[];
  final removed = <({String familyId, String userId})>[];
  final transfers = <({String familyId, String newOwner, String former})>[];
  final resent = <String>[];
  final revoked = <String>[];
  Completer<void>? resendGate;

  @override
  Future<String> createRootFamily(String name) async {
    createdNames.add(name);
    return 'created-1';
  }

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async {}

  @override
  Future<void> addCoOwner({
    required String familyId,
    required String userId,
  }) async {
    added.add((familyId: familyId, userId: userId));
  }

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) async {
    demoted.add((familyId: familyId, userId: userId));
    final current = directory.detail;
    if (current == null) return;
    directory.detail = FamilyDetail(
      id: current.id,
      name: current.name,
      myRole: current.myRole,
      people: [
        for (final person in current.people)
          person.userId == userId
              ? FamilyPerson(
                  userId: person.userId,
                  role: 'member',
                  displayName: person.displayName,
                )
              : person,
      ],
      pendingInvites: current.pendingInvites,
    );
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async {
    removed.add((familyId: familyId, userId: userId));
  }

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) async {
    transfers.add((
      familyId: familyId,
      newOwner: newOwnerUserId,
      former: formerOwnerBecomes,
    ));
  }

  @override
  Future<void> softDeleteFamily(String familyId) async {
    deleted.add(familyId);
  }

  @override
  Future<DateTime> resendInvite(String inviteId) async {
    final gate = resendGate;
    resendGate = null;
    if (gate != null) await gate.future;
    resent.add(inviteId);
    return DateTime(2026, 10, 17);
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    revoked.add(inviteId);
  }

  @override
  Future<void> recoverFamily(String familyId) async {
    recovered.add(familyId);
    directory.directory = const FamilyDirectory(
      active: [
        FamilyRoster(
          id: 'old-1',
          name: 'West Archive',
          role: 'co_owner',
          memberCount: 1,
          publishedCount: 0,
        ),
      ],
      recoverable: [],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/features/family/family_role.dart';
import 'package:tell_me_a_story/features/family/family_tree_order.dart';
import 'package:tell_me_a_story/features/family/manage_families_page.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('dropdown order: families, divider, invite, branch, Manage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final families = [
      MemberFamily(id: 'zed', name: 'Zed', createdAt: DateTime.utc(2022)),
      MemberFamily(
        id: 'amy',
        name: 'The Amy',
        parentFamilyId: 'ada',
        branchYear: 1950,
        createdAt: DateTime.utc(2021),
      ),
      MemberFamily(id: 'ada', name: 'Ada', createdAt: DateTime.utc(2020)),
    ];
    await tester.pumpWidget(
      _header(
        families: families,
        currentId: 'ada',
        familyName: 'Ada',
        onStartTimeline: () {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();

    final rows = nestFamilies(families);
    var previous = -1.0;
    for (final row in rows) {
      final y = tester
          .getTopLeft(find.byKey(Key('family-menu-item-${row.family.id}')))
          .dy;
      expect(y, greaterThan(previous));
      previous = y;
    }
    final dividerY = tester
        .getTopLeft(find.byKey(const Key('family-menu-divider')))
        .dy;
    final inviteY = tester
        .getTopLeft(find.byKey(const Key('family-menu-invite')))
        .dy;
    final branchY = tester
        .getTopLeft(find.byKey(const Key('family-menu-start-timeline')))
        .dy;
    final manageY = tester
        .getTopLeft(find.byKey(const Key('family-menu-manage')))
        .dy;
    expect(previous, lessThan(dividerY));
    expect(dividerY, lessThan(inviteY));
    expect(inviteY, lessThan(branchY));
    expect(branchY, lessThan(manageY));
    expect(find.text('Invite a family member to Ada'), findsOneWidget);
    expect(find.text('Add a family branch to Ada'), findsOneWidget);
    expect(find.byKey(const Key('family-menu-start')), findsNothing);
    expect(find.text('Related families'), findsNothing);
  });

  testWidgets('invite row hides when canWrite is false', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Ada',
            families: [
              MemberFamily(
                id: 'ada',
                name: 'Ada',
                createdAt: DateTime.utc(2020),
              ),
            ],
            currentFamilyId: 'ada',
            onFamilySelected: (_) {},
            canWrite: false,
            onInvite: () {},
            onStartTimeline: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-invite')), findsNothing);
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-invite')), findsNothing);
    expect(find.byKey(const Key('family-menu-start-timeline')), findsOneWidget);
  });

  testWidgets('capture menu hides invite and still offers a branch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.capture,
            familyName: 'Ada',
            families: [
              MemberFamily(
                id: 'ada',
                name: 'Ada',
                createdAt: DateTime.utc(2020),
              ),
            ],
            currentFamilyId: 'ada',
            onFamilySelected: (_) {},
            canWrite: true,
            onInvite: () {},
            onStartTimeline: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search archive...'), findsNothing);
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-invite')), findsNothing);
    expect(find.byKey(const Key('family-menu-start-timeline')), findsOneWidget);
  });

  testWidgets('closed family name wraps two lines and keeps the full tooltip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name =
        'The extraordinarily long Morgan family archive name that wraps';
    await tester.pumpWidget(
      _header(
        families: [
          MemberFamily(id: 'ada', name: name, createdAt: DateTime.utc(2020)),
        ],
        currentId: 'ada',
        familyName: name,
      ),
    );
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text(name));
    expect(label.maxLines, 2);
    expect(label.overflow, TextOverflow.ellipsis);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
    expect(paragraph.size.height, greaterThan(28));
    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('family-menu')),
    );
    expect(menu.tooltip, name);
    final search = tester.getSize(find.byKey(const Key('timeline-search')));
    expect(search.width, greaterThanOrEqualTo(40));
    expect(search.height, greaterThanOrEqualTo(40));
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('timeline-search')),
        matching: find.byIcon(Icons.search),
      ),
    );
    expect(icon.color, albumInk);
  });

  testWidgets('sage guide stops above the post-families divider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _header(
        families: [
          MemberFamily(id: 'ada', name: 'Ada', createdAt: DateTime.utc(2020)),
          MemberFamily(
            id: 'amy',
            name: 'Amy',
            parentFamilyId: 'ada',
            branchYear: 1950,
            createdAt: DateTime.utc(2021),
          ),
        ],
        currentId: 'ada',
        familyName: 'Ada',
        onStartTimeline: () {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    final line = find.descendant(
      of: find.byKey(const Key('family-menu-item-amy')),
      matching: find.byType(ColoredBox),
    );
    expect(line, findsOneWidget);
    final guideBottom = tester.getRect(line).bottom;
    final dividerTop = tester
        .getTopLeft(find.byKey(const Key('family-menu-divider')))
        .dy;
    expect(guideBottom, lessThan(dividerTop));
    final invite = find.byKey(const Key('family-menu-invite'));
    final icon = tester.widget<Icon>(
      find.descendant(
        of: invite,
        matching: find.byIcon(Icons.person_add_outlined),
      ),
    );
    expect(icon.size, 19);
    expect(icon.color, albumSage);
  });

  testWidgets('search, New story, and avatar sit 12px apart', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _header(
        families: [
          MemberFamily(id: 'ada', name: 'Ada', createdAt: DateTime.utc(2020)),
        ],
        currentId: 'ada',
        familyName: 'Ada',
      ),
    );
    await tester.pumpAndSettle();
    final search = tester.getRect(find.byKey(const Key('timeline-search')));
    final story = tester.getRect(
      find.widgetWithText(FilledButton, 'New story'),
    );
    final avatar = tester.getRect(find.byKey(const Key('header-avatar')));
    expect(story.left - search.right, closeTo(12, 0.1));
    expect(avatar.left - story.right, closeTo(12, 0.1));
    expect(search.width, greaterThanOrEqualTo(40));
    expect(search.height, greaterThanOrEqualTo(40));
  });

  testWidgets('child rows indent 24px per level under their parent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _header(
        families: [
          MemberFamily(id: 'root', name: 'Root', createdAt: DateTime.utc(2020)),
          MemberFamily(
            id: 'child',
            name: 'Child',
            parentFamilyId: 'root',
            branchYear: 1980,
            createdAt: DateTime.utc(2021),
          ),
          MemberFamily(
            id: 'grand',
            name: 'Grand',
            parentFamilyId: 'child',
            branchYear: 2001,
            createdAt: DateTime.utc(2022),
          ),
        ],
        currentId: 'root',
        familyName: 'Root',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();

    double dx(String id) {
      return tester.getTopLeft(find.byKey(Key('family-monogram-$id'))).dx;
    }

    final root = dx('root');
    expect(dx('child'), root + 24);
    expect(dx('grand'), root + 48);
  });

  testWidgets(
    'current family has a terracotta check and a medium-weight name',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _header(
          families: [
            MemberFamily(id: 'ada', name: 'Ada', createdAt: DateTime.utc(2020)),
            MemberFamily(id: 'bea', name: 'Bea', createdAt: DateTime.utc(2021)),
          ],
          currentId: 'ada',
          familyName: 'Ada',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('family-menu')));
      await tester.pumpAndSettle();

      final item = find.byKey(const Key('family-menu-item-ada'));
      final icon = tester.widget<Icon>(
        find.descendant(of: item, matching: find.byIcon(Icons.check)),
      );
      expect(icon.color, albumTerracotta);
      expect(find.byIcon(Icons.check), findsOneWidget);
      final name = tester.widget<Text>(
        find.descendant(of: item, matching: find.text('Ada')),
      );
      expect(name.style?.fontWeight, FontWeight.w500);
    },
  );

  testWidgets('picking a nested family from Drafts lands on its timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const ada = 'ada';
    const kid = 'kid';
    final router = GoRouter(
      initialLocation: AppRoutes.drafts,
      routes: [
        GoRoute(
          path: AppRoutes.drafts,
          builder: (context, state) => _switchScreen(
            page: AlbumHeaderPage.drafts,
            currentId: ada,
            kid: kid,
          ),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => const Text('timeline-landed'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-$kid')));
    await tester.pumpAndSettle();
    expect(FamilySelection.id, kid);
    expect(router.state.uri.path, AppRoutes.timeline);
  });

  testWidgets(
    'Manage families shows for a members-only user and opens the hub',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: AppRoutes.drafts,
        routes: [
          GoRoute(
            path: AppRoutes.drafts,
            builder: (context, state) => Scaffold(
              appBar: AlbumHeader(
                page: AlbumHeaderPage.drafts,
                familyName: 'Cousin',
                families: [
                  MemberFamily(
                    id: 'mem',
                    name: 'Cousin',
                    role: 'member',
                    createdAt: DateTime.utc(2020),
                  ),
                ],
                currentFamilyId: 'mem',
                onFamilySelected: (_) {},
                stewarded: const [],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.manageFamilies,
            builder: (context, state) => const Text('hub-landed'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('family-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
      await tester.tap(find.byKey(const Key('family-menu-manage')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.manageFamilies);
    },
  );

  testWidgets(
    'owner hub stays as today when listStewarded has a family that counts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final directory = _EmptyDirectory(
        directory: const FamilyDirectory(
          active: [
            FamilyRoster(
              id: 'ada',
              name: 'Ada Archive',
              role: 'owner',
              memberCount: 2,
              publishedCount: 1,
            ),
          ],
          recoverable: [],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ManageFamiliesPage(
            directoryApi: directory,
            familiesApi: _Families(
              stewarded: const [
                StewardFamily(id: 'ada', name: 'Ada Archive', role: 'owner'),
              ],
            ),
            manageApi: _NoManage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hub-monogram-ada')), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
      expect(find.byWidgetPredicate(_memberKey), findsNothing);
    },
  );

  testWidgets(
    'non-owner hub lists nested families with role labels and no admin tools',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mine = [
        MemberFamily(
          id: 'parent',
          name: 'Parent',
          role: 'member',
          createdAt: DateTime.utc(2020),
        ),
        MemberFamily(
          id: 'child',
          name: 'Child',
          parentFamilyId: 'parent',
          branchYear: 1980,
          role: 'owner',
          createdAt: DateTime.utc(2021),
        ),
        MemberFamily(
          id: 'co',
          name: 'The Co',
          parentFamilyId: 'parent',
          branchYear: 1990,
          role: 'co_owner',
          createdAt: DateTime.utc(2022),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ManageFamiliesPage(
            directoryApi: _EmptyDirectory(),
            familiesApi: _Families(
              mine: mine,
              stewarded: [
                StewardFamily(
                  id: 'gone',
                  name: 'Gone',
                  role: 'owner',
                  deletedAt: DateTime.now().toUtc().subtract(
                    const Duration(days: 70),
                  ),
                ),
              ],
            ),
            manageApi: _NoManage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rows = nestFamilies(mine);
      var previous = -1.0;
      for (final row in rows) {
        final y = tester
            .getTopLeft(
              find.byKey(Key('manage-families-member-${row.family.id}')),
            )
            .dy;
        expect(y, greaterThan(previous));
        previous = y;
        expect(
          find.text(familyRoleLabel(row.family.role ?? 'member')),
          findsWidgets,
        );
      }
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Co-owner'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('3 active'), findsOneWidget);
      expect(find.byWidgetPredicate(_hubMonogramKey), findsNothing);
      expect(find.text('Recoverable (60 days)'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );

  testWidgets('non-owner hub row switches family and opens the timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.manageFamilies,
      routes: [
        GoRoute(
          path: AppRoutes.manageFamilies,
          builder: (context, state) => ManageFamiliesPage(
            directoryApi: _EmptyDirectory(),
            familiesApi: _Families(
              mine: [
                MemberFamily(
                  id: 'mem',
                  name: 'Cousin',
                  role: 'member',
                  createdAt: DateTime.utc(2020),
                ),
              ],
            ),
            manageApi: _NoManage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => const Text('timeline-landed'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manage-families-member-mem')));
    await tester.pumpAndSettle();
    expect(FamilySelection.id, 'mem');
    expect(router.state.uri.path, AppRoutes.timeline);
  });

  testWidgets(
    'non-owner hub with no families shows only title, subtitle and Start',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ManageFamiliesPage(
            directoryApi: _EmptyDirectory(),
            familiesApi: _Families(),
            manageApi: _NoManage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manage families'), findsOneWidget);
      expect(
        find.text(
          'Switch between your active family archives or create a new shared space.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your families'), findsNothing);
      expect(find.byKey(const Key('manage-families-start')), findsOneWidget);
    },
  );
}

Widget _header({
  required List<MemberFamily> families,
  required String currentId,
  required String familyName,
  AlbumHeaderPage page = AlbumHeaderPage.timeline,
  VoidCallback? onStartTimeline,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AlbumHeader(
        page: page,
        familyName: familyName,
        families: families,
        currentFamilyId: currentId,
        onFamilySelected: (_) {},
        stewarded: const [],
        onStartTimeline: onStartTimeline,
      ),
    ),
  );
}

Widget _switchScreen({
  required AlbumHeaderPage page,
  required String currentId,
  required String kid,
}) {
  return Scaffold(
    appBar: AlbumHeader(
      page: page,
      familyName: 'Ada',
      families: [
        MemberFamily(id: currentId, name: 'Ada', createdAt: DateTime.utc(2020)),
        MemberFamily(
          id: kid,
          name: 'Kid',
          parentFamilyId: currentId,
          branchYear: 1988,
          createdAt: DateTime.utc(2021),
        ),
      ],
      currentFamilyId: currentId,
      onFamilySelected: FamilySelection.remember,
      stewarded: const [],
    ),
  );
}

bool _memberKey(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('manage-families-member');
}

bool _hubMonogramKey(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('hub-monogram-');
}

class _Families extends FamiliesGateway {
  _Families({this.mine = const [], this.stewarded = const []});

  final List<MemberFamily> mine;
  final List<StewardFamily> stewarded;

  @override
  Future<List<MemberFamily>> listMine() async => mine;

  @override
  Future<List<StewardFamily>> listStewarded() async => stewarded;
}

class _EmptyDirectory implements FamilyDirectoryGateway {
  _EmptyDirectory({
    this.directory = const FamilyDirectory(active: [], recoverable: []),
  });

  final FamilyDirectory directory;

  @override
  Future<FamilyDirectory> listDirectory() async => directory;

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async => null;
}

Never _manageCalled() => throw StateError('ManageFamiliesGateway called');

class _NoManage implements ManageFamiliesGateway {
  _NoManage();

  @override
  dynamic noSuchMethod(Invocation invocation) => _manageCalled();

  @override
  Future<String> createRootFamily(String name) => _manageCalled();

  @override
  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  }) => _manageCalled();

  @override
  Future<void> renameFamily({required String familyId, required String name}) =>
      _manageCalled();

  @override
  Future<void> addCoOwner({required String familyId, required String userId}) =>
      _manageCalled();

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) => _manageCalled();

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) => _manageCalled();

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) => _manageCalled();

  @override
  Future<void> softDeleteFamily(String familyId) => _manageCalled();

  @override
  Future<void> recoverFamily(String familyId) => _manageCalled();

  @override
  Future<DateTime> resendInvite(String inviteId) => _manageCalled();

  @override
  Future<void> revokeInvite(String inviteId) => _manageCalled();
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/family_roster.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';
import 'package:tell_me_a_story/core/widgets/family/family_tree_order.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/fakes/fake_manage_families_repository.dart';
import '../../../support/album_test_scope.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'dropdown order: families, divider, tree, invite, branch, Manage',
    (tester) async {
      final container = albumTestContainer();
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
      await pumpScoped(
        tester,
        container,
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
      final treeY = tester
          .getTopLeft(find.byKey(const Key('family-menu-tree')))
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
      expect(dividerY, lessThan(treeY));
      expect(treeY, lessThan(inviteY));
      expect(inviteY, lessThan(branchY));
      expect(branchY, lessThan(manageY));
      expect(find.text('See the whole family tree'), findsOneWidget);
      expect(find.text('Invite a family member to Ada'), findsOneWidget);
      expect(find.text('Add a family branch to Ada'), findsOneWidget);
      expect(find.byKey(const Key('family-menu-start')), findsNothing);
      expect(find.text('Related families'), findsNothing);
    },
  );

  testWidgets('invite row hides when canWrite is false', (tester) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
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
    expect(find.byKey(const Key('family-menu-tree')), findsOneWidget);
  });

  testWidgets('capture menu hides invite and still offers a branch', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
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
    expect(find.byKey(const Key('family-menu-tree')), findsNothing);
  });

  testWidgets(
    'closed family name stays one line and uses the room before the nav',
    (tester) async {
      final container = albumTestContainer();
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const name =
          'The extraordinarily long Morgan family archive name that wraps';
      await pumpScoped(
        tester,
        container,
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
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.size.height, lessThan(36));
      expect(paragraph.size.width, greaterThan(40));
      expect(find.byTooltip(name), findsWidgets);
      final menuRect = tester.getRect(find.byKey(const Key('family-menu')));
      final navRect = tester.getRect(
        find.byKey(const Key('header-nav-stories')),
      );
      expect(menuRect.right, lessThanOrEqualTo(navRect.left));
      expect(menuRect.width, greaterThan(80));
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
    },
  );

  testWidgets('closed family control has no filled bar at rest', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
      _header(
        families: [
          MemberFamily(id: 'ada', name: 'Ada', createdAt: DateTime.utc(2020)),
        ],
        currentId: 'ada',
        familyName: 'Ada',
      ),
    );
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('family-menu'));
    expect(
      find.descendant(of: menu, matching: find.byType(Material)),
      findsNothing,
    );
    expect(
      find.descendant(of: menu, matching: find.byType(InkWell)),
      findsNothing,
    );
    final fills = tester.widgetList<DecoratedBox>(
      find.descendant(of: menu, matching: find.byType(DecoratedBox)),
    );
    for (final box in fills) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        expect(decoration.color!.a, 0);
      }
    }
    expect(
      find.descendant(of: menu, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    final menuRect = tester.getRect(menu);
    final navRect = tester.getRect(find.byKey(const Key('header-nav-stories')));
    expect(navRect.left - menuRect.right, greaterThan(80));
    final label = tester.widget<Text>(find.text('Ada'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
  });

  testWidgets('a name longer than the slot ellipsizes on one line', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name =
        'The extraordinarily long Morgan family archive name that wraps ';
    final huge = name * 8;
    await pumpScoped(
      tester,
      container,
      _header(
        families: [
          MemberFamily(id: 'ada', name: huge, createdAt: DateTime.utc(2020)),
        ],
        currentId: 'ada',
        familyName: huge,
      ),
    );
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text(huge));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(huge));
    expect(paragraph.size.height, lessThan(36));
    expect(paragraph.size.width, greaterThan(40));
    expect(paragraph.didExceedMaxLines, isTrue);
    final menuRect = tester.getRect(find.byKey(const Key('family-menu')));
    final navRect = tester.getRect(find.byKey(const Key('header-nav-stories')));
    expect(menuRect.right, lessThanOrEqualTo(navRect.left));
    expect(find.byTooltip(huge), findsWidgets);
  });

  testWidgets('sage guide stops above the post-families divider', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
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
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
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
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
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
      final container = albumTestContainer();
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpScoped(
        tester,
        container,
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

  testWidgets('picking a nested family from Drafts lands on Family Landing', (
    tester,
  ) async {
    final container = albumTestContainer();
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
            container: container,
            page: AlbumHeaderPage.drafts,
            currentId: ada,
            kid: kid,
          ),
        ),
        GoRoute(
          path: AppRoutes.familyLanding,
          builder: (context, state) => const Text('landing-landed'),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => const Text('timeline-landed'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-$kid')));
    await tester.pumpAndSettle();
    expect(container.read(familySelectionProvider), kid);
    expect(router.state.uri.path, AppRoutes.familyLanding);
  });

  testWidgets('the tree row opens the current family tree page', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.drafts,
      routes: [
        GoRoute(
          path: AppRoutes.drafts,
          builder: (context, state) => _switchScreen(
            container: container,
            page: AlbumHeaderPage.drafts,
            currentId: 'ada',
            kid: 'kid',
          ),
        ),
        GoRoute(
          path: AppRoutes.familyTree,
          builder: (context, state) =>
              Text('tree-${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-tree')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.familyTreePath('ada'));
    expect(find.text('tree-ada'), findsOneWidget);
  });

  testWidgets('the tree page hides its own tree row', (tester) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
      MaterialApp(
        home: _switchScreen(
          container: container,
          page: AlbumHeaderPage.familyTree,
          currentId: 'ada',
          kid: 'kid',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
    expect(find.byKey(const Key('family-menu-tree')), findsNothing);
  });

  testWidgets('no current family, no tree row', (tester) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScoped(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.drafts,
            familyName: 'Family',
            families: const [],
            currentFamilyId: null,
            onFamilySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
    expect(find.byKey(const Key('family-menu-tree')), findsNothing);
  });

  testWidgets(
    'Manage families shows for a members-only user and opens the hub',
    (tester) async {
      final container = albumTestContainer();
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
      await pumpScoped(
        tester,
        container,
        MaterialApp.router(routerConfig: router),
      );
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
      final container = albumTestContainer(
        _hub(
          directory: directory,
          families: _Families(
            stewarded: const [
              StewardFamily(id: 'ada', name: 'Ada Archive', role: 'owner'),
            ],
          ),
        ),
      );
      await pumpScoped(
        tester,
        container,
        const MaterialApp(home: ManageFamiliesPage()),
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
      final container = albumTestContainer(
        _hub(
          families: _Families(
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
        ),
      );
      await pumpScoped(
        tester,
        container,
        const MaterialApp(home: ManageFamiliesPage()),
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

  testWidgets('non-owner hub row switches family and opens Family Landing', (
    tester,
  ) async {
    final container = albumTestContainer(
      _hub(
        families: _Families(
          mine: [
            MemberFamily(
              id: 'mem',
              name: 'Cousin',
              role: 'member',
              createdAt: DateTime.utc(2020),
            ),
          ],
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.manageFamilies,
      routes: [
        GoRoute(
          path: AppRoutes.manageFamilies,
          builder: (context, state) => const ManageFamiliesPage(),
        ),
        GoRoute(
          path: AppRoutes.familyLanding,
          builder: (context, state) => const Text('landing-landed'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manage-families-member-mem')));
    await tester.pumpAndSettle();
    expect(container.read(familySelectionProvider), 'mem');
    expect(router.state.uri.path, AppRoutes.familyLanding);
  });

  testWidgets(
    'non-owner hub with no families shows only title, subtitle and Start',
    (tester) async {
      final container = albumTestContainer(_hub(families: _Families()));
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpScoped(
        tester,
        container,
        const MaterialApp(home: ManageFamiliesPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manage families'), findsOneWidget);
      expect(
        find.text(
          'Switch between your active family archives or create a new shared space.',
        ),
        findsNothing,
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
  required ProviderContainer container,
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
      onFamilySelected: (id) =>
          container.read(familySelectionProvider.notifier).remember(id),
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

class _Families extends FamiliesRepository {
  _Families({this.mine = const [], this.stewarded = const []});

  final List<MemberFamily> mine;
  final List<StewardFamily> stewarded;

  @override
  Future<List<MemberFamily>> listMine() async => mine;

  @override
  Future<List<StewardFamily>> listStewarded() async => stewarded;
}

class _EmptyDirectory implements FamilyDirectoryRepository {
  _EmptyDirectory({
    this.directory = const FamilyDirectory(active: [], recoverable: []),
  });

  final FamilyDirectory directory;

  @override
  Future<FamilyDirectory> listDirectory() async => directory;

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async => null;
}

/// Hub repositories: [directory] (empty by default), [families], and a
/// manage repository these flows must not use.
List<Override> _hub({
  FamilyDirectoryRepository? directory,
  required FamiliesRepository families,
}) {
  return [
    familyDirectoryRepositoryProvider.overrideWithValue(
      directory ?? _EmptyDirectory(),
    ),
    familiesRepositoryProvider.overrideWithValue(families),
    manageFamiliesRepositoryProvider.overrideWithValue(_noManage()),
    inviteRepositoryProvider.overrideWithValue(
      FakeInviteRepository(familyId: null),
    ),
  ];
}

/// A manage gateway that fails every call: these flows must not use it.
FakeManageFamiliesRepository _noManage() =>
    FakeManageFamiliesRepository()
      ..error = StateError('ManageFamiliesRepository called');

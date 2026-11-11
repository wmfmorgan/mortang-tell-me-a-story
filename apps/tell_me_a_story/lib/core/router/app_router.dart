import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/features/auth/presentation/invite_sign_in_page.dart';
import 'package:tell_me_a_story/features/auth/presentation/sign_in_page.dart';
import 'package:tell_me_a_story/features/settings/presentation/settings_page.dart';
import 'package:tell_me_a_story/features/drafts/presentation/drafts_page.dart';
import 'package:tell_me_a_story/features/perspectives/presentation/add_perspective_page.dart';
import 'package:tell_me_a_story/features/stories/presentation/new_story_page.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/features/search/presentation/search_page.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_page.dart';
import 'package:tell_me_a_story/features/family/presentation/family_landing_page.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_family_page.dart';
import 'package:tell_me_a_story/features/stories/presentation/story_reader_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_page.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';

part 'app_router.g.dart';

/// Transparent route used for the story reader and the capture form.
CustomTransitionPage<void> albumModalPage({
  required LocalKey pageKey,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: pageKey,
    opaque: false,
    barrierDismissible: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondary, child) => child,
    child: child,
  );
}

const signInFromParam = 'from';

/// The app path a signed-out visit asked for (`?from=` on sign-in), or
/// null when absent or not an in-app path.
String? signInReturnPath(Uri signInUri) {
  final from = signInUri.queryParameters[signInFromParam];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null || path == AppRoutes.signIn) return null;
  return from;
}

/// Where a signed-in session opens from the sign-in route.
///
/// A live family lands on Family Landing. No live family, with a soft-deleted
/// family the caller still owns or co-owns, lands on the manage hub. Neither
/// live family nor a failed lookup lands on the timeline empty Start state.
Future<String> appStartPath(FamiliesRepository families) async {
  try {
    final live = await families.listMine();
    if (live.isNotEmpty) return AppRoutes.familyLanding;
    final stewarded = await families.listStewarded();
    if (stewarded.any((family) => family.countsForManage())) {
      return AppRoutes.manageFamilies;
    }
  } catch (error, stack) {
    _reportRouterError(error, stack);
    return AppRoutes.familyLanding;
  }
  return AppRoutes.timeline;
}

void _reportRouterError(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'app router'),
  );
}

/// The app's route table. Repositories come from providers; [AuthRefresh]
/// drives redirects on sign-in and sign-out.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authRefresh = ref.watch(authRefreshProvider);
  final families = ref.read(familiesRepositoryProvider);
  // context.push keeps the page under it. The address bar still shows the
  // pushed path, including the reader modal.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  Future<bool> storyOnExit(BuildContext context, GoRouterState state) {
    if (!authRefresh.isSignedIn) return Future<bool>.value(true);
    return UnsavedGuards.onExit(context, state);
  }

  final router = GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) =>
        _redirect(ref, authRefresh, families, state),
    routes: [
      ..._familyRoutes(ref),
      ..._storyRoutes(storyOnExit),
      ..._otherRoutes(),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// A path parameter of the matched route.
String _param(GoRouterState state, String name) {
  // go_router matches the route only when its `:name` segment is present.
  return state.pathParameters[name]!;
}

Future<String?> _redirect(
  Ref ref,
  AuthRefresh auth,
  FamiliesRepository families,
  GoRouterState state,
) async {
  final signedIn = auth.isSignedIn;
  final loc = state.matchedLocation;
  final onSignIn = loc == AppRoutes.signIn;
  final onInvite = loc.startsWith('/invite/');
  final inviteToken = state.uri.queryParameters['invite'];
  if (inviteToken != null && inviteToken.isNotEmpty && !onInvite) {
    return AppRoutes.invitePath(inviteToken);
  }
  if (!signedIn && !onSignIn && !onInvite) {
    if (auth.signedInThisRun) return AppRoutes.signIn;
    return Uri(
      path: AppRoutes.signIn,
      queryParameters: {signInFromParam: state.uri.toString()},
    ).toString();
  }
  if (signedIn && onSignIn) {
    return signInReturnPath(state.uri) ?? await appStartPath(families);
  }
  if (signedIn && loc == AppRoutes.newStory) {
    final familyId = ref.read(familySelectionProvider);
    if (familyId != null) return _newStoryRedirect(families, familyId);
  }
  if (signedIn && loc == AppRoutes.familyLanding) {
    return _landingRedirect(ref, families);
  }
  return null;
}

/// New story for a family the caller no longer belongs to goes home.
Future<String?> _newStoryRedirect(
  FamiliesRepository families,
  String familyId,
) async {
  try {
    final mine = await families.listMine();
    if (!mine.any((family) => family.id == familyId)) {
      if (mine.isNotEmpty) return AppRoutes.familyLanding;
      return AppRoutes.timeline;
    }
  } catch (error, stack) {
    _reportRouterError(error, stack);
    return AppRoutes.familyLanding;
  }
  return null;
}

/// Family Landing without a live selected family moves to manage or start.
Future<String?> _landingRedirect(Ref ref, FamiliesRepository families) async {
  try {
    final mine = await families.listMine();
    final selected = ref.read(familySelectionProvider);
    final selectedLive =
        selected != null && mine.any((family) => family.id == selected);
    if (selectedLive) return null;
    if (selected != null) {
      final stewarded = await families.listStewarded();
      final deleted = stewarded.any(
        (family) => family.id == selected && family.deletedAt != null,
      );
      if (deleted) return AppRoutes.manageFamilies;
    }
    if (mine.isEmpty) {
      final next = await appStartPath(families);
      if (next != AppRoutes.familyLanding) return next;
    }
  } catch (error, stack) {
    _reportRouterError(error, stack);
    return null;
  }
  return null;
}

List<RouteBase> _familyRoutes(Ref ref) {
  return [
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const SignInPage(),
    ),
    GoRoute(
      path: AppRoutes.familyLanding,
      builder: (context, state) => const FamilyLandingPage(),
    ),
    GoRoute(
      path: AppRoutes.timeline,
      builder: (context, state) => const TimelinePage(),
    ),
    GoRoute(
      path: AppRoutes.allStories,
      builder: (context, state) =>
          AllStoriesPage(familyId: _param(state, 'id')),
    ),
    GoRoute(
      path: AppRoutes.familyTree,
      builder: (context, state) =>
          FamilyTreePage(familyId: _param(state, 'id')),
    ),
    GoRoute(
      path: AppRoutes.manageFamilies,
      builder: (context, state) => const ManageFamiliesPage(),
    ),
    GoRoute(
      path: AppRoutes.manageFamily,
      builder: (context, state) => ManageFamilyPage(
        familyId: _param(state, 'familyId'),
        currentUserId: ref.read(appSessionProvider).currentUserId,
      ),
    ),
  ];
}

List<RouteBase> _storyRoutes(ExitCallback storyOnExit) {
  return [
    GoRoute(
      path: AppRoutes.newStory,
      onExit: storyOnExit,
      pageBuilder: (context, state) {
        final draft = state.uri.queryParameters['draft'];
        return albumModalPage(
          pageKey: state.pageKey,
          child: NewStoryPage(
            draftId: (draft != null && draft.isNotEmpty) ? draft : null,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.storyEdit,
      onExit: storyOnExit,
      pageBuilder: (context, state) => albumModalPage(
        pageKey: state.pageKey,
        child: NewStoryPage(editStoryId: state.pathParameters['storyId']),
      ),
    ),
    GoRoute(
      path: AppRoutes.storyPerspective,
      builder: (context, state) {
        final extra = state.extra;
        return AddPerspectivePage(
          storyId: _param(state, 'storyId'),
          familyId: extra is String ? extra : null,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.story,
      pageBuilder: (context, state) => albumModalPage(
        pageKey: state.pageKey,
        child: StoryReaderPage(storyId: _param(state, 'storyId')),
      ),
    ),
  ];
}

List<RouteBase> _otherRoutes() {
  return [
    GoRoute(
      path: AppRoutes.invite,
      builder: (context, state) =>
          InviteSignInPage(token: Uri.decodeComponent(_param(state, 'token'))),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.drafts,
      builder: (context, state) => const DraftsPage(),
    ),
  ];
}

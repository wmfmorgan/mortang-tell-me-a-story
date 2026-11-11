import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/data/comments_repository.dart';
import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/data/invite_repository.dart';
import 'package:tell_me_a_story/core/data/mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/data/people_repository.dart';
import 'package:tell_me_a_story/core/data/perspectives_repository.dart'
    hide displayNameOrMember;
import 'package:tell_me_a_story/core/data/photos_repository.dart';
import 'package:tell_me_a_story/core/data/places_repository.dart';
import 'package:tell_me_a_story/core/data/profile_repository.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/features/auth/presentation/invite_sign_in_page.dart';
import 'package:tell_me_a_story/features/auth/presentation/sign_in_page.dart';
import 'package:tell_me_a_story/features/settings/presentation/settings_page.dart';
import 'package:tell_me_a_story/features/drafts/presentation/drafts_page.dart';
import 'package:tell_me_a_story/features/perspectives/presentation/add_perspective_page.dart';
import 'package:tell_me_a_story/features/stories/presentation/new_story_page.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/features/search/presentation/search_page.dart';
import 'package:tell_me_a_story/core/data/manage_families_repository.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_page.dart';
import 'package:tell_me_a_story/features/family/presentation/family_landing_page.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_family_page.dart';
import 'package:tell_me_a_story/features/search/presentation/search_recents.dart';
import 'package:tell_me_a_story/features/stories/presentation/story_reader_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_page.dart';
import 'package:tell_me_a_story/features/search/data/search_repository.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';

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

/// Where a signed-in session opens from the sign-in route.
///
/// A live family lands on Family Landing. No live family, with a soft-deleted
/// family the caller still owns or co-owns, lands on the manage hub. Neither
/// live family nor a failed lookup lands on the timeline empty Start state.
Future<String> appStartPath(FamiliesRepository? families) async {
  if (families == null) return AppRoutes.familyLanding;
  try {
    final live = await families.listMine();
    if (live.isNotEmpty) return AppRoutes.familyLanding;
    final stewarded = await families.listStewarded();
    if (stewarded.any((family) => family.countsForManage())) {
      return AppRoutes.manageFamilies;
    }
  } catch (_) {
    return AppRoutes.familyLanding;
  }
  return AppRoutes.timeline;
}

GoRouter createAppRouter({
  required AuthRefresh authRefresh,
  InviteRepository? inviteApi,
  PeopleRepository? peopleApi,
  PlacesRepository? placesApi,
  MapboxSearchRepository? mapboxSearch,
  StoriesRepository? storiesApi,
  PhotosRepository? photosApi,
  CommentsRepository? commentsApi,
  PerspectivesRepository? perspectivesApi,
  SearchRepository? searchApi,
  SearchRecents? searchRecents,
  ProfileRepository? profileApi,
  FamiliesRepository? familiesApi,
  FamilyDirectoryRepository? directoryApi,
  ManageFamiliesRepository? manageApi,
  Future<void> Function()? onLogout,
}) {
  final recents = searchRecents ?? SearchRecents();
  // context.push keeps the page under it. The address bar still shows the
  // pushed path, including the reader modal.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  Future<bool> storyOnExit(BuildContext context, GoRouterState state) {
    if (!authRefresh.isSignedIn) return Future<bool>.value(true);
    return UnsavedGuards.onExit(context, state);
  }

  return GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) async {
      final signedIn = authRefresh.isSignedIn;
      final loc = state.matchedLocation;
      final onSignIn = loc == AppRoutes.signIn;
      final onInvite = loc.startsWith('/invite/');
      final inviteToken = state.uri.queryParameters['invite'];
      if (inviteToken != null && inviteToken.isNotEmpty && !onInvite) {
        return AppRoutes.invitePath(inviteToken);
      }

      if (!signedIn && !onSignIn && !onInvite) {
        return AppRoutes.signIn;
      }
      if (signedIn && onSignIn) {
        return appStartPath(familiesApi);
      }
      if (signedIn && loc == AppRoutes.newStory && familiesApi != null) {
        final familyId = FamilySelection.id;
        if (familyId != null) {
          try {
            final mine = await familiesApi.listMine();
            if (!mine.any((family) => family.id == familyId)) {
              if (mine.isNotEmpty) return AppRoutes.familyLanding;
              return AppRoutes.timeline;
            }
          } catch (_) {
            return AppRoutes.familyLanding;
          }
        }
      }
      if (signedIn && loc == AppRoutes.familyLanding && familiesApi != null) {
        try {
          final mine = await familiesApi.listMine();
          final selected = FamilySelection.id;
          final selectedLive =
              selected != null && mine.any((family) => family.id == selected);
          if (!selectedLive) {
            if (selected != null) {
              final stewarded = await familiesApi.listStewarded();
              final deleted = stewarded.any(
                (family) => family.id == selected && family.deletedAt != null,
              );
              if (deleted) return AppRoutes.manageFamilies;
            }
            if (mine.isEmpty) {
              final next = await appStartPath(familiesApi);
              if (next != AppRoutes.familyLanding) return next;
            }
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.familyLanding,
        builder: (context, state) => FamilyLandingPage(
          api: inviteApi,
          storiesApi: storiesApi,
          familiesApi: familiesApi,
          photosApi: photosApi,
          peopleApi: peopleApi,
          manageApi: manageApi,
        ),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) => TimelinePage(
          api: inviteApi,
          storiesApi: storiesApi,
          familiesApi: familiesApi,
          peopleApi: peopleApi,
        ),
      ),
      GoRoute(
        path: AppRoutes.allStories,
        builder: (context, state) => AllStoriesPage(
          familyId: state.pathParameters['id']!,
          storiesApi: storiesApi,
          familiesApi: familiesApi,
          photosApi: photosApi,
        ),
      ),
      GoRoute(
        path: AppRoutes.familyTree,
        builder: (context, state) => FamilyTreePage(
          familyId: state.pathParameters['id']!,
          storiesApi: storiesApi,
          familiesApi: familiesApi,
        ),
      ),
      GoRoute(
        path: AppRoutes.newStory,
        onExit: storyOnExit,
        pageBuilder: (context, state) {
          final draft = state.uri.queryParameters['draft'];
          return albumModalPage(
            pageKey: state.pageKey,
            child: NewStoryPage(
              inviteApi: inviteApi,
              peopleApi: peopleApi,
              placesApi: placesApi,
              mapboxSearch: mapboxSearch,
              storiesApi: storiesApi,
              photosApi: photosApi,
              draftId: (draft != null && draft.isNotEmpty) ? draft : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.invite,
        builder: (context, state) => InviteSignInPage(
          token: Uri.decodeComponent(state.pathParameters['token']!),
          inviteApi: inviteApi,
          authRefresh: authRefresh,
          signedIn: () => authRefresh.isSignedIn,
        ),
      ),
      GoRoute(
        path: AppRoutes.storyEdit,
        onExit: storyOnExit,
        pageBuilder: (context, state) => albumModalPage(
          pageKey: state.pageKey,
          child: NewStoryPage(
            inviteApi: inviteApi,
            peopleApi: peopleApi,
            placesApi: placesApi,
            mapboxSearch: mapboxSearch,
            storiesApi: storiesApi,
            photosApi: photosApi,
            editStoryId: state.pathParameters['storyId'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.storyPerspective,
        builder: (context, state) {
          final extra = state.extra;
          return AddPerspectivePage(
            storyId: state.pathParameters['storyId']!,
            familyId: extra is String ? extra : null,
            perspectivesApi: perspectivesApi,
            storiesApi: storiesApi,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.story,
        pageBuilder: (context, state) {
          return albumModalPage(
            pageKey: state.pageKey,
            child: StoryReaderPage(
              storyId: state.pathParameters['storyId']!,
              storiesApi: storiesApi,
              peopleApi: peopleApi,
              placesApi: placesApi,
              photosApi: photosApi,
              commentsApi: commentsApi,
              perspectivesApi: perspectivesApi,
              profileApi: profileApi,
              familiesApi: familiesApi,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => SearchPage(
          inviteApi: inviteApi,
          peopleApi: peopleApi,
          searchApi: searchApi,
          photosApi: photosApi,
          recents: recents,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => SettingsPage(
          profileApi: profileApi,
          familiesApi: familiesApi,
          inviteApi: inviteApi,
          peopleApi: peopleApi,
          onLogout: onLogout,
        ),
      ),
      GoRoute(
        path: AppRoutes.manageFamilies,
        builder: (context, state) => ManageFamiliesPage(
          directoryApi: directoryApi,
          familiesApi: familiesApi,
          manageApi: manageApi,
          inviteApi: inviteApi,
          peopleApi: peopleApi,
          onLogout: onLogout,
        ),
      ),
      GoRoute(
        path: AppRoutes.manageFamily,
        builder: (context, state) => ManageFamilyPage(
          familyId: state.pathParameters['familyId']!,
          directoryApi: directoryApi,
          familiesApi: familiesApi,
          manageApi: manageApi,
          inviteApi: inviteApi,
          peopleApi: peopleApi,
          onLogout: onLogout,
          currentUserId: AppSession.instance.currentUserId,
        ),
      ),
      GoRoute(
        path: AppRoutes.drafts,
        builder: (context, state) => DraftsPage(
          inviteApi: inviteApi,
          storiesApi: storiesApi,
          familiesApi: familiesApi,
          peopleApi: peopleApi,
        ),
      ),
    ],
  );
}

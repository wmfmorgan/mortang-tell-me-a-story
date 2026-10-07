import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/comments_api.dart';
import '../../data/families_api.dart';
import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/perspectives_api.dart' hide displayNameOrMember;
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/profile_api.dart';
import '../../data/stories_api.dart';
import '../../features/auth/magic_link_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/drafts/drafts_page.dart';
import '../../features/perspectives/add_perspective_page.dart';
import '../../features/stories/new_story_page.dart';
import '../../features/search/search_page.dart';
import '../../data/manage_families_api.dart';
import '../../features/family/manage_families_page.dart';
import '../../features/family/manage_family_page.dart';
import '../../features/search/search_recents.dart';
import '../../features/stories/story_reader_page.dart';
import '../../features/timeline/timeline_page.dart';
import '../../data/search_api.dart';
import 'auth_refresh.dart';

/// Chrome-lock paths: magic-link entry (signed-out), `/timeline` (signed-in).
abstract final class AppRoutes {
  static const magicLink = '/';
  static const timeline = '/timeline';
  static const newStory = '/stories/new';
  static const story = '/stories/:storyId';
  static const storyPerspective = '/stories/:storyId/perspective';
  static const drafts = '/drafts';
  static const search = '/search';
  static const settings = '/settings';
  static const manageFamilies = '/manage-families';
  static const manageFamily = '/manage-families/:familyId';

  static String storyPath(String id) => '/stories/$id';

  static String manageFamilyPath(String id) => '/manage-families/$id';

  static String storyPerspectivePath(String id) => '/stories/$id/perspective';
}

GoRouter createAppRouter({
  required AuthRefresh authRefresh,
  InviteGateway? inviteApi,
  PeopleGateway? peopleApi,
  PlacesGateway? placesApi,
  MapboxSearchGateway? mapboxSearch,
  StoriesGateway? storiesApi,
  PhotosGateway? photosApi,
  CommentsGateway? commentsApi,
  PerspectivesGateway? perspectivesApi,
  SearchGateway? searchApi,
  SearchRecents? searchRecents,
  ProfileGateway? profileApi,
  FamiliesGateway? familiesApi,
  FamilyDirectoryGateway? directoryApi,
  ManageFamiliesGateway? manageApi,
  Future<void> Function()? onLogout,
}) {
  final recents = searchRecents ?? SearchRecents();
  // context.push keeps the page under it. The address bar still shows the
  // pushed path, including the reader modal.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: AppRoutes.magicLink,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) {
      final signedIn = authRefresh.isSignedIn;
      final loc = state.matchedLocation;
      final onMagicLink = loc == AppRoutes.magicLink;
      final invite = state.uri.queryParameters['invite'];
      final inviteSuffix = (invite != null && invite.isNotEmpty)
          ? '?invite=$invite'
          : '';

      if (!signedIn && !onMagicLink) {
        // Preserve invite token across auth (no dedicated /invite route).
        return '${AppRoutes.magicLink}$inviteSuffix';
      }
      if (signedIn && onMagicLink) {
        return '${AppRoutes.timeline}$inviteSuffix';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.magicLink,
        builder: (context, state) => const MagicLinkPage(),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) =>
            TimelinePage(api: inviteApi, storiesApi: storiesApi),
      ),
      GoRoute(
        path: AppRoutes.newStory,
        builder: (context, state) {
          final draft = state.uri.queryParameters['draft'];
          return NewStoryPage(
            inviteApi: inviteApi,
            peopleApi: peopleApi,
            placesApi: placesApi,
            mapboxSearch: mapboxSearch,
            storiesApi: storiesApi,
            photosApi: photosApi,
            draftId: (draft != null && draft.isNotEmpty) ? draft : null,
          );
        },
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
          final modal = state.extra == ReaderPresentation.modal;
          final page = StoryReaderPage(
            storyId: state.pathParameters['storyId']!,
            storiesApi: storiesApi,
            peopleApi: peopleApi,
            placesApi: placesApi,
            photosApi: photosApi,
            commentsApi: commentsApi,
            perspectivesApi: perspectivesApi,
            profileApi: profileApi,
            presentation: modal
                ? ReaderPresentation.modal
                : ReaderPresentation.page,
          );
          if (!modal) {
            return MaterialPage<void>(key: state.pageKey, child: page);
          }
          return CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: false,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            transitionsBuilder: (context, animation, secondary, child) => child,
            child: page,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => SearchPage(
          inviteApi: inviteApi,
          peopleApi: peopleApi,
          placesApi: placesApi,
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
          onLogout: onLogout,
        ),
      ),
      GoRoute(
        path: AppRoutes.drafts,
        builder: (context, state) => DraftsPage(
          inviteApi: inviteApi,
          storiesApi: storiesApi,
          photosApi: photosApi,
        ),
      ),
    ],
  );
}

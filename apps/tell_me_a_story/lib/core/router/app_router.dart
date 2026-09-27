import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/stories_api.dart';
import '../../features/auth/magic_link_page.dart';
import '../../features/drafts/drafts_page.dart';
import '../../features/stories/new_story_page.dart';
import '../../features/timeline/timeline_page.dart';
import 'auth_refresh.dart';

/// Chrome-lock paths: magic-link entry (signed-out), `/timeline` (signed-in).
abstract final class AppRoutes {
  static const magicLink = '/';
  static const timeline = '/timeline';
  static const newStory = '/stories/new';
  static const drafts = '/drafts';
}

GoRouter createAppRouter({
  required AuthRefresh authRefresh,
  InviteGateway? inviteApi,
  PeopleGateway? peopleApi,
  PlacesGateway? placesApi,
  MapboxSearchGateway? mapboxSearch,
  StoriesGateway? storiesApi,
  PhotosGateway? photosApi,
}) {
  return GoRouter(
    initialLocation: AppRoutes.magicLink,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) {
      final signedIn = authRefresh.isSignedIn;
      final loc = state.matchedLocation;
      final onMagicLink = loc == AppRoutes.magicLink;
      final invite = state.uri.queryParameters['invite'];
      final inviteSuffix =
          (invite != null && invite.isNotEmpty) ? '?invite=$invite' : '';

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
        builder: (context, state) => TimelinePage(
          api: inviteApi,
          storiesApi: storiesApi,
        ),
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

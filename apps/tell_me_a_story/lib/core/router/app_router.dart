import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/comments_api.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/perspectives_api.dart' hide displayNameOrMember;
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/profile_api.dart';
import '../../data/stories_api.dart';
import '../../features/auth/invite_sign_in_page.dart';
import '../../features/auth/magic_link_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/drafts/drafts_page.dart';
import '../../features/perspectives/add_perspective_page.dart';
import '../../features/stories/new_story_page.dart';
import '../navigation/unsaved_guard.dart';
import '../../features/search/search_page.dart';
import '../../data/manage_families_api.dart';
import '../../features/family/family_landing_page.dart';
import '../../features/family/manage_families_page.dart';
import '../../features/family/manage_family_page.dart';
import '../../features/search/search_recents.dart';
import '../../features/stories/story_reader_page.dart';
import '../../features/timeline/timeline_page.dart';
import '../../data/search_api.dart';
import '../theme/album_theme.dart';
import 'auth_refresh.dart';

/// Pops the current route, or opens the timeline when this page is the root.
void popOrGoTimeline(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.timeline);
    }
    return;
  }
  Navigator.of(context).pop();
}

/// Card, scrim, and icon label shared by the reader and the capture form.
class AlbumModalFrame extends StatelessWidget {
  const AlbumModalFrame({
    super.key,
    required this.frameKey,
    required this.label,
    required this.trailing,
    required this.child,
    this.markKey,
    this.showScrim = true,
  });

  final Key frameKey;
  final Key? markKey;
  final String label;
  final Widget trailing;
  final Widget child;
  final bool showScrim;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (showScrim)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const ColoredBox(color: albumModalScrim),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1040,
                  maxHeight: height - 48,
                ),
                child: Material(
                  key: frameKey,
                  color: albumParchment,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: albumModalBorder),
                  ),
                  child: Scaffold(
                    backgroundColor: albumParchment,
                    body: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                key: markKey,
                                color: albumTerracotta,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: albumSage,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: trailing,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

/// Chrome-lock paths: magic-link entry (signed-out), `/family` (signed-in home).
abstract final class AppRoutes {
  static const magicLink = '/';
  static const familyLanding = '/family';
  static const timeline = '/timeline';
  static const newStory = '/stories/new';
  static const story = '/stories/:storyId';
  static const storyEdit = '/stories/:storyId/edit';
  static const storyPerspective = '/stories/:storyId/perspective';
  static const invite = '/invite/:token';
  static const drafts = '/drafts';
  static const search = '/search';
  static const settings = '/settings';
  static const manageFamilies = '/manage-families';
  static const manageFamily = '/manage-families/:familyId';

  static String storyPath(String id) => '/stories/$id';

  static String storyEditPath(String id) => '/stories/$id/edit';

  static String invitePath(String token) => '/invite/$token';

  static String manageFamilyPath(String id) => '/manage-families/$id';

  static String storyPerspectivePath(String id) => '/stories/$id/perspective';
}

/// Where a signed-in session opens from the magic-link route.
///
/// A live family lands on Family Landing. No live family, with a soft-deleted
/// family the caller still owns or co-owns, lands on the manage hub. Neither
/// live family nor a failed lookup lands on the timeline empty Start state.
Future<String> appStartPath(FamiliesGateway? families) async {
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
  Future<bool> storyOnExit(BuildContext context, GoRouterState state) {
    if (!authRefresh.isSignedIn) return Future<bool>.value(true);
    return UnsavedGuards.onExit(context, state);
  }

  return GoRouter(
    initialLocation: AppRoutes.magicLink,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) async {
      final signedIn = authRefresh.isSignedIn;
      final loc = state.matchedLocation;
      final onMagicLink = loc == AppRoutes.magicLink;
      final onInvite = loc.startsWith('/invite/');
      final inviteToken = state.uri.queryParameters['invite'];
      if (inviteToken != null && inviteToken.isNotEmpty && !onInvite) {
        return AppRoutes.invitePath(inviteToken);
      }

      if (!signedIn && !onMagicLink && !onInvite) {
        return AppRoutes.magicLink;
      }
      if (signedIn && onMagicLink) {
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
        path: AppRoutes.magicLink,
        builder: (context, state) => const MagicLinkPage(),
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
          currentUserId: _signedInUserId(),
        ),
      ),
      GoRoute(
        path: AppRoutes.drafts,
        builder: (context, state) => DraftsPage(
          inviteApi: inviteApi,
          storiesApi: storiesApi,
          photosApi: photosApi,
          familiesApi: familiesApi,
          peopleApi: peopleApi,
        ),
      ),
    ],
  );
}

String? _signedInUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

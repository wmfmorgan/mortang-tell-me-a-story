import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/magic_link_page.dart';
import '../../features/timeline/timeline_page.dart';
import 'auth_refresh.dart';

/// Chrome-lock paths for M1: magic-link entry (signed-out), `/timeline` (signed-in).
abstract final class AppRoutes {
  static const magicLink = '/';
  static const timeline = '/timeline';
}

GoRouter createAppRouter({required AuthRefresh authRefresh}) {
  return GoRouter(
    initialLocation: AppRoutes.magicLink,
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) {
      final signedIn = authRefresh.isSignedIn;
      final onMagicLink = state.matchedLocation == AppRoutes.magicLink;

      if (!signedIn && !onMagicLink) {
        return AppRoutes.magicLink;
      }
      if (signedIn && onMagicLink) {
        return AppRoutes.timeline;
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
        builder: (context, state) => const TimelinePage(),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/invite_api.dart';
import '../../features/auth/magic_link_page.dart';
import '../../features/timeline/timeline_page.dart';
import 'auth_refresh.dart';

/// Chrome-lock paths: magic-link entry (signed-out), `/timeline` (signed-in).
abstract final class AppRoutes {
  static const magicLink = '/';
  static const timeline = '/timeline';
}

GoRouter createAppRouter({
  required AuthRefresh authRefresh,
  InviteGateway? inviteApi,
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
        builder: (context, state) => TimelinePage(api: inviteApi),
      ),
    ],
  );
}

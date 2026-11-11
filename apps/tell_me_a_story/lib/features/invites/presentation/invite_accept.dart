import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/data/invite_repository.dart';

/// After session exists, accept `?invite=` token and land on Family Landing.
Future<void> acceptInviteFromUriIfPresent({
  required BuildContext context,
  required Uri uri,
  InviteRepository? api,
}) async {
  final token = uri.queryParameters['invite']?.trim();
  if (token == null || token.isEmpty) return;

  final inviteApi = api ?? ServerInviteRepository();
  try {
    await inviteApi.acceptInvite(token: token);
  } catch (_) {
    // No dedicated accept-error surface. Still open Family Landing.
  }
  if (!context.mounted) return;
  context.go(AppRoutes.familyLanding);
}

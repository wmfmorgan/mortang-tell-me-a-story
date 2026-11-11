import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';

/// After session exists, accept `?invite=` token and land on Family Landing.
Future<void> acceptInviteFromUriIfPresent({
  required BuildContext context,
  required WidgetRef ref,
  required Uri uri,
}) async {
  final token = uri.queryParameters['invite']?.trim();
  if (token == null || token.isEmpty) return;

  try {
    await ref.read(inviteRepositoryProvider).acceptInvite(token: token);
  } on AppException {
    // No dedicated accept-error surface. Family Landing opens either way.
  }
  if (!context.mounted) return;
  context.go(AppRoutes.familyLanding);
}

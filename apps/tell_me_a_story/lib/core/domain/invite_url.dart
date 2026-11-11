import 'package:tell_me_a_story/core/env.dart';

/// Shareable invite path. Old `?invite=` links still rewrite in the router.
String buildInviteUrl(String token, {String? origin}) {
  final base = (origin ?? Env.inviteAppOrigin).replaceAll(RegExp(r'/+$'), '');
  return '$base/invite/${Uri.encodeComponent(token)}';
}

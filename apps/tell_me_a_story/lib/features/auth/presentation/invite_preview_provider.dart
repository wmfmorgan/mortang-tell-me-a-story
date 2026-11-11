import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/invite_link_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_preview.dart';

part 'invite_preview_provider.g.dart';

/// What the `/invite/:token` page shows about [token]'s family.
@riverpod
Future<InvitePreview> invitePreview(Ref ref, String token) =>
    ref.watch(inviteLinkRepositoryProvider).validateInviteToken(token);

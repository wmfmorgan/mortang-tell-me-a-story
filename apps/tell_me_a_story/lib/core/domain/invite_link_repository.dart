import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/invite_preview.dart';

part 'invite_link_repository.g.dart';

/// Unauthenticated `invitePublic.preview`. Not part of InviteRepository.
abstract class InviteLinkRepository {
  Future<InvitePreview> validateInviteToken(String token);
}

@Riverpod(keepAlive: true)
InviteLinkRepository inviteLinkRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/accept_invite_result.dart';
import 'package:tell_me_a_story/core/domain/create_invite_result.dart';

part 'invite_repository.g.dart';

/// Invite data/API surface (M2). UI stays on timeline chrome.
abstract class InviteRepository {
  Future<String?> currentFamilyId();
  Future<String> createFamily(String name);
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  });

  /// Emails the invite. [token] is the one [createInvite] returned; the
  /// server keeps only its hash.
  Future<void> sendInviteEmail({
    required String inviteId,
    required String token,
  });
  Future<AcceptInviteResult> acceptInvite({required String token});
}

@Riverpod(keepAlive: true)
InviteRepository inviteRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

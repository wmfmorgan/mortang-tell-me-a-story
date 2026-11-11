import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/domain/accept_invite_result.dart';
import 'package:tell_me_a_story/core/domain/create_invite_result.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';

class ServerInviteRepository implements InviteRepository {
  /// [currentFamilyId] reads the remembered family (the session's
  /// `familySelectionProvider` in the app).
  ServerInviteRepository({
    server.Client? client,
    required String? Function() currentFamilyId,
  }) : _injected = client,
       _rememberedFamilyId = currentFamilyId;

  final server.Client? _injected;
  final String? Function() _rememberedFamilyId;

  server.Client get _client => _injected ?? serverClient;

  /// The remembered family when the caller is still a member of it,
  /// otherwise the caller's first live family. Null when signed out.
  @override
  Future<String?> currentFamilyId() async {
    if (!_client.auth.isAuthenticated) return null;
    final rows = await withServerErrors(() => _client.family.listMine());
    final ids = [for (final row in rows) row.id.toString()];
    final remembered = _rememberedFamilyId();
    if (remembered != null && ids.contains(remembered)) return remembered;
    return ids.isEmpty ? null : ids.first;
  }

  @override
  Future<String> createFamily(String name) async {
    final id = await withServerErrors(() => _client.family.createRoot(name));
    return id.toString();
  }

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    final trimmed = email?.trim();
    final dto = await withServerErrors(
      () => _client.invite.create(
        server.UuidValue.fromString(familyId),
        email: trimmed == null || trimmed.isEmpty ? null : trimmed,
        personId: personId == null || personId.isEmpty
            ? null
            : server.UuidValue.fromString(personId),
      ),
    );
    return CreateInviteResult(
      inviteId: dto.inviteId.toString(),
      token: dto.token,
      expiresAt: dto.expiresAt,
      inviteUrl: dto.inviteUrl,
    );
  }

  @override
  Future<void> sendInviteEmail({
    required String inviteId,
    required String token,
  }) {
    return withServerErrors(
      () => _client.invite.sendEmail(
        server.UuidValue.fromString(inviteId),
        token,
      ),
    );
  }

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    final familyId = await withServerErrors(() => _client.invite.accept(token));
    return AcceptInviteResult(familyId: familyId.toString());
  }
}

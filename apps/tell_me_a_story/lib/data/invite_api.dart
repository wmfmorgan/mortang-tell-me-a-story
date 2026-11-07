import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import '../core/config/env.dart';
import '../core/server/server_client.dart';
import 'family_selection.dart';
import 'server/server_errors.dart';

/// Shareable invite path. Old `?invite=` links still rewrite in the router.
String buildInviteUrl(String token, {String? origin}) {
  final base = (origin ?? Env.inviteAppOrigin).replaceAll(RegExp(r'/+$'), '');
  return '$base/invite/${Uri.encodeComponent(token)}';
}

/// Invite data/API surface (M2). UI stays on timeline chrome.
abstract class InviteGateway {
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

class InviteApi implements InviteGateway {
  InviteApi({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  /// The remembered family when the caller is still a member of it,
  /// otherwise the caller's first live family. Null when signed out.
  @override
  Future<String?> currentFamilyId() async {
    if (!_client.auth.isAuthenticated) return null;
    final rows = await withServerErrors(() => _client.family.listMine());
    final ids = [for (final row in rows) row.id.toString()];
    final remembered = FamilySelection.id;
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

class CreateInviteResult {
  const CreateInviteResult({
    required this.inviteId,
    required this.token,
    required this.expiresAt,
    required this.inviteUrl,
  });

  final String inviteId;
  final String token;
  final DateTime expiresAt;
  final String inviteUrl;
}

class AcceptInviteResult {
  const AcceptInviteResult({required this.familyId});

  final String familyId;
}

class InvitePreview {
  const InvitePreview({
    required this.valid,
    this.familyId,
    this.familyName,
    this.inviterName,
  });

  final bool valid;
  final String? familyId;
  final String? familyName;
  final String? inviterName;
}

/// Unauthenticated `invitePublic.preview`. Not part of [InviteGateway].
abstract class InviteLinkGateway {
  Future<InvitePreview> validateInviteToken(String token);
}

class InviteLinkApi implements InviteLinkGateway {
  InviteLinkApi({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<InvitePreview> validateInviteToken(String token) async {
    final dto = await withServerErrors(
      () => _client.invitePublic.preview(token),
    );
    return InvitePreview(
      valid: dto.valid,
      familyId: dto.familyId?.toString(),
      familyName: dto.familyName,
      inviterName: dto.inviterName,
    );
  }
}

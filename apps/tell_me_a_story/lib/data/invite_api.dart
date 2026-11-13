import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import 'family_selection.dart';
import 'profile_session.dart';

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
  Future<void> sendInviteEmail({required String inviteId});
  Future<AcceptInviteResult> acceptInvite({required String token});
}

/// Thin Edge client for Design Doc invite contracts.
class InviteApi implements InviteGateway {
  InviteApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String?> currentFamilyId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      FamilySelection.clear();
      ProfileSession.instance.clear();
      return resolveCurrentFamilyId(userId: null, remembered: null);
    }
    ProfileSession.instance.bindUser(uid);
    final remembered = FamilySelection.bindUser(uid);
    if (remembered != null) {
      final membershipIds = await _membershipFamilyIds(uid);
      if (membershipIds.contains(remembered)) return remembered;
    }
    final row = await _client
        .from('memberships')
        .select('family_id, families!inner(deleted_at)')
        .eq('user_id', uid)
        .isFilter('families.deleted_at', null)
        .limit(1)
        .maybeSingle();
    return row?['family_id'] as String?;
  }

  Future<List<String>> _membershipFamilyIds(String uid) async {
    final rows = await _client
        .from('memberships')
        .select('family_id, families!inner(deleted_at)')
        .eq('user_id', uid)
        .isFilter('families.deleted_at', null);
    final ids = <String>[];
    for (final row in rows) {
      final id = row['family_id'];
      if (id is String) ids.add(id);
    }
    return ids;
  }

  /// Data/API create family (US-1). No dedicated Create Family screen in M2.
  @override
  Future<String> createFamily(String name) async {
    final res = await _client.rpc('create_family', params: {'p_name': name});
    if (res is Map && res['id'] != null) return res['id'] as String;
    throw StateError('create_family returned unexpected payload');
  }

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    final body = <String, dynamic>{'family_id': familyId};
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (personId != null && personId.isNotEmpty) {
      body['person_id'] = personId;
    }
    final json = await _invoke('create-invite', body, expectStatus: 201);
    return CreateInviteResult(
      inviteId: json['invite_id'] as String,
      token: json['token'] as String,
      expiresAt: json['expires_at'] as String,
      inviteUrl: json['invite_url'] as String,
    );
  }

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {
    await _invoke('send-invite-email', {'invite_id': inviteId});
  }

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    final json = await _invoke('accept-invite', {'token': token});
    return AcceptInviteResult(
      familyId: json['family_id'] as String,
      membershipId: json['membership_id'] as String,
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body, {
    int expectStatus = 200,
  }) async {
    if (_client.auth.currentSession == null) {
      throw InviteApiException(
        code: 'AUTH_REQUIRED',
        message: 'Sign-in required',
      );
    }
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final decoded = _asMap(res.data);
      if (res.status != expectStatus) {
        throw InviteApiException(
          code: decoded['code'] as String? ?? 'VALIDATION',
          message: decoded['message'] as String? ?? 'Request failed',
        );
      }
      return decoded;
    } on FunctionException catch (e) {
      final decoded = _asMap(e.details);
      throw InviteApiException(
        code: decoded['code'] as String? ?? 'VALIDATION',
        message:
            decoded['message'] as String? ?? e.reasonPhrase ?? 'Request failed',
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    return switch (data) {
      final Map<String, dynamic> m => m,
      final Map m => Map<String, dynamic>.from(m),
      _ => <String, dynamic>{},
    };
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
  final String expiresAt;
  final String inviteUrl;
}

class AcceptInviteResult {
  const AcceptInviteResult({
    required this.familyId,
    required this.membershipId,
  });

  final String familyId;
  final String membershipId;
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

/// Unauthenticated GET of validate-invite-token. Not part of [InviteGateway].
abstract class InviteLinkGateway {
  Future<InvitePreview> validateInviteToken(String token);
}

class InviteLinkApi implements InviteLinkGateway {
  InviteLinkApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<InvitePreview> validateInviteToken(String token) async {
    final res = await _client.functions.invoke(
      'validate-invite-token',
      method: HttpMethod.get,
      queryParameters: {'token': token},
    );
    final data = res.data;
    if (data is! Map) return const InvitePreview(valid: false);
    final map = Map<String, dynamic>.from(data);
    return InvitePreview(
      valid: map['valid'] == true,
      familyId: map['family_id'] as String?,
      familyName: map['family_name'] as String?,
      inviterName: map['inviter_name'] as String?,
    );
  }
}

class InviteApiException implements Exception {
  InviteApiException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'InviteApiException($code: $message)';
}

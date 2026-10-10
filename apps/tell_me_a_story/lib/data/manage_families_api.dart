import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ManageFamiliesGateway {
  Future<String> createRootFamily(String name);
  Future<void> renameFamily({required String familyId, required String name});
  Future<void> addCoOwner({required String familyId, required String userId});
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  });
  Future<void> removeMember({required String familyId, required String userId});
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  });
  Future<void> softDeleteFamily(String familyId);
  Future<void> recoverFamily(String familyId);
  Future<DateTime> resendInvite(String inviteId);
  Future<void> revokeInvite(String inviteId);
}

class ManageFamiliesApi implements ManageFamiliesGateway {
  ManageFamiliesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> createRootFamily(String name) async {
    final json = await _invoke('create-root-family', {
      'name': name,
    }, expectStatus: 201);
    final id = json['family_id'];
    if (id is! String || id.isEmpty) {
      throw ManageFamiliesException(
        code: 'VALIDATION',
        message: 'create_family returned no id',
      );
    }
    return id;
  }

  @override
  Future<void> renameFamily({required String familyId, required String name}) {
    return _invoke('rename-family', {'family_id': familyId, 'name': name});
  }

  @override
  Future<void> addCoOwner({required String familyId, required String userId}) {
    return _invoke('add-co-owner', {'family_id': familyId, 'user_id': userId});
  }

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) {
    return _invoke('remove-co-owner', {
      'family_id': familyId,
      'user_id': userId,
    });
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) {
    return _invoke('remove-member', {'family_id': familyId, 'user_id': userId});
  }

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) {
    return _invoke('transfer-ownership', {
      'family_id': familyId,
      'new_owner_user_id': newOwnerUserId,
      'former_owner_becomes': formerOwnerBecomes,
    });
  }

  @override
  Future<void> softDeleteFamily(String familyId) {
    return _invoke('soft-delete-family', {'family_id': familyId});
  }

  @override
  Future<void> recoverFamily(String familyId) {
    return _invoke('recover-family', {'family_id': familyId});
  }

  @override
  Future<DateTime> resendInvite(String inviteId) async {
    final json = await _invoke('resend-invite', {'invite_id': inviteId});
    final raw = json['expires_at'];
    final expires = raw is String ? DateTime.tryParse(raw) : null;
    if (expires == null) {
      throw ManageFamiliesException(
        code: 'VALIDATION',
        message: 'resend_invite returned no expires_at',
      );
    }
    return expires;
  }

  @override
  Future<void> revokeInvite(String inviteId) {
    return _invoke('revoke-invite', {'invite_id': inviteId});
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body, {
    int expectStatus = 200,
  }) async {
    if (_client.auth.currentSession == null) {
      throw ManageFamiliesException(
        code: 'AUTH_REQUIRED',
        message: 'Sign-in required',
      );
    }
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final decoded = _asMap(res.data);
      if (res.status != expectStatus) {
        throw ManageFamiliesException(
          code: decoded['code'] as String? ?? 'VALIDATION',
          message: decoded['message'] as String? ?? 'Request failed',
        );
      }
      return decoded;
    } on ManageFamiliesException {
      rethrow;
    } on FunctionException catch (e) {
      final decoded = _asMap(e.details);
      throw ManageFamiliesException(
        code: decoded['code'] as String? ?? 'VALIDATION',
        message:
            decoded['message'] as String? ?? e.reasonPhrase ?? 'Request failed',
      );
    }
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  return switch (data) {
    final Map<String, dynamic> m => m,
    final Map m => Map<String, dynamic>.from(m),
    _ => <String, dynamic>{},
  };
}

class ManageFamiliesException implements Exception {
  ManageFamiliesException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'ManageFamiliesException($code: $message)';
}

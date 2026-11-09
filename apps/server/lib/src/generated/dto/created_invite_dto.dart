/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

/// Returned once by InviteEndpoint.create; token is never stored (only its hash).
abstract class CreatedInviteDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CreatedInviteDto._({
    required this.inviteId,
    required this.token,
    required this.expiresAt,
    required this.inviteUrl,
  });

  factory CreatedInviteDto({
    required _is.UuidValue inviteId,
    required String token,
    required DateTime expiresAt,
    required String inviteUrl,
  }) = _CreatedInviteDtoImpl;

  factory CreatedInviteDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreatedInviteDto(
      inviteId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['inviteId'],
      ),
      token: jsonSerialization['token'] as String,
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      inviteUrl: jsonSerialization['inviteUrl'] as String,
    );
  }

  _is.UuidValue inviteId;

  String token;

  DateTime expiresAt;

  String inviteUrl;

  /// Returns a shallow copy of this [CreatedInviteDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CreatedInviteDto copyWith({
    _is.UuidValue? inviteId,
    String? token,
    DateTime? expiresAt,
    String? inviteUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreatedInviteDto',
      'inviteId': inviteId.toJson(),
      'token': token,
      'expiresAt': expiresAt.toJson(),
      'inviteUrl': inviteUrl,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CreatedInviteDto',
      'inviteId': inviteId.toJson(),
      'token': token,
      'expiresAt': expiresAt.toJson(),
      'inviteUrl': inviteUrl,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _CreatedInviteDtoImpl extends CreatedInviteDto {
  _CreatedInviteDtoImpl({
    required _is.UuidValue inviteId,
    required String token,
    required DateTime expiresAt,
    required String inviteUrl,
  }) : super._(
         inviteId: inviteId,
         token: token,
         expiresAt: expiresAt,
         inviteUrl: inviteUrl,
       );

  /// Returns a shallow copy of this [CreatedInviteDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CreatedInviteDto copyWith({
    _is.UuidValue? inviteId,
    String? token,
    DateTime? expiresAt,
    String? inviteUrl,
  }) {
    return CreatedInviteDto(
      inviteId: inviteId ?? this.inviteId,
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
      inviteUrl: inviteUrl ?? this.inviteUrl,
    );
  }
}

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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// An invite that is not accepted or revoked. sentAt is invites.lastSentAt.
abstract class PendingInviteDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PendingInviteDto._({
    required this.id,
    this.email,
    this.personId,
    required this.sentAt,
    required this.expiresAt,
    required this.createdAt,
  });

  factory PendingInviteDto({
    required _isc.UuidValue id,
    String? email,
    _isc.UuidValue? personId,
    required DateTime sentAt,
    required DateTime expiresAt,
    required DateTime createdAt,
  }) = _PendingInviteDtoImpl;

  factory PendingInviteDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PendingInviteDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      email: jsonSerialization['email'] as String?,
      personId: jsonSerialization['personId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['personId']),
      sentAt: _isc.DateTimeJsonExtension.fromJson(jsonSerialization['sentAt']),
      expiresAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  _isc.UuidValue id;

  String? email;

  _isc.UuidValue? personId;

  DateTime sentAt;

  DateTime expiresAt;

  DateTime createdAt;

  /// Returns a shallow copy of this [PendingInviteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PendingInviteDto copyWith({
    _isc.UuidValue? id,
    String? email,
    _isc.UuidValue? personId = const _isc.$UndefinedUuidValue(),
    DateTime? sentAt,
    DateTime? expiresAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PendingInviteDto',
      'id': id.toJson(),
      if (email != null) 'email': email,
      if (personId != null) 'personId': personId?.toJson(),
      'sentAt': sentAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PendingInviteDto',
      'id': id.toJson(),
      if (email != null) 'email': email,
      if (personId != null) 'personId': personId?.toJson(),
      'sentAt': sentAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PendingInviteDtoImpl extends PendingInviteDto {
  _PendingInviteDtoImpl({
    required _isc.UuidValue id,
    String? email,
    _isc.UuidValue? personId,
    required DateTime sentAt,
    required DateTime expiresAt,
    required DateTime createdAt,
  }) : super._(
         id: id,
         email: email,
         personId: personId,
         sentAt: sentAt,
         expiresAt: expiresAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [PendingInviteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PendingInviteDto copyWith({
    _isc.UuidValue? id,
    Object? email = _Undefined,
    _isc.UuidValue? personId = const _isc.$UndefinedUuidValue(),
    DateTime? sentAt,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return PendingInviteDto(
      id: id ?? this.id,
      email: email is String? ? email : this.email,
      personId: personId is _isc.UndefinedSentinel ? this.personId : personId,
      sentAt: sentAt ?? this.sentAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

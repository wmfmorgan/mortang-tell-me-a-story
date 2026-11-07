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

import '../membership_role.dart' as _id460rmf;

/// A member of a family. No email: other users' emails are not exposed.
abstract class FamilyMemberDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FamilyMemberDto._({
    required this.userId,
    required this.role,
    this.displayName,
    this.avatarKey,
  });

  factory FamilyMemberDto({
    required _isc.UuidValue userId,
    required _id460rmf.MembershipRole role,
    String? displayName,
    String? avatarKey,
  }) = _FamilyMemberDtoImpl;

  factory FamilyMemberDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return FamilyMemberDto(
      userId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      role: _id460rmf.MembershipRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      displayName: jsonSerialization['displayName'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
    );
  }

  _isc.UuidValue userId;

  _id460rmf.MembershipRole role;

  String? displayName;

  String? avatarKey;

  /// Returns a shallow copy of this [FamilyMemberDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FamilyMemberDto copyWith({
    _isc.UuidValue? userId,
    _id460rmf.MembershipRole? role,
    String? displayName,
    String? avatarKey,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FamilyMemberDto',
      'userId': userId.toJson(),
      'role': role.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (avatarKey != null) 'avatarKey': avatarKey,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FamilyMemberDto',
      'userId': userId.toJson(),
      'role': role.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (avatarKey != null) 'avatarKey': avatarKey,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FamilyMemberDtoImpl extends FamilyMemberDto {
  _FamilyMemberDtoImpl({
    required _isc.UuidValue userId,
    required _id460rmf.MembershipRole role,
    String? displayName,
    String? avatarKey,
  }) : super._(
         userId: userId,
         role: role,
         displayName: displayName,
         avatarKey: avatarKey,
       );

  /// Returns a shallow copy of this [FamilyMemberDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FamilyMemberDto copyWith({
    _isc.UuidValue? userId,
    _id460rmf.MembershipRole? role,
    Object? displayName = _Undefined,
    Object? avatarKey = _Undefined,
  }) {
    return FamilyMemberDto(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      displayName: displayName is String? ? displayName : this.displayName,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
    );
  }
}

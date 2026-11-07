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

/// One row of the family directory.
abstract class FamilyRosterDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FamilyRosterDto._({
    required this.id,
    required this.name,
    required this.role,
    required this.memberCount,
    required this.publishedCount,
    this.deletedAt,
  });

  factory FamilyRosterDto({
    required _isc.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole role,
    required int memberCount,
    required int publishedCount,
    DateTime? deletedAt,
  }) = _FamilyRosterDtoImpl;

  factory FamilyRosterDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return FamilyRosterDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      name: jsonSerialization['name'] as String,
      role: _id460rmf.MembershipRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      memberCount: jsonSerialization['memberCount'] as int,
      publishedCount: jsonSerialization['publishedCount'] as int,
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  _isc.UuidValue id;

  String name;

  _id460rmf.MembershipRole role;

  int memberCount;

  int publishedCount;

  DateTime? deletedAt;

  /// Returns a shallow copy of this [FamilyRosterDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FamilyRosterDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? role,
    int? memberCount,
    int? publishedCount,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FamilyRosterDto',
      'id': id.toJson(),
      'name': name,
      'role': role.toJson(),
      'memberCount': memberCount,
      'publishedCount': publishedCount,
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FamilyRosterDto',
      'id': id.toJson(),
      'name': name,
      'role': role.toJson(),
      'memberCount': memberCount,
      'publishedCount': publishedCount,
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _FamilyRosterDtoImpl extends FamilyRosterDto {
  _FamilyRosterDtoImpl({
    required _isc.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole role,
    required int memberCount,
    required int publishedCount,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         name: name,
         role: role,
         memberCount: memberCount,
         publishedCount: publishedCount,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [FamilyRosterDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FamilyRosterDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? role,
    int? memberCount,
    int? publishedCount,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  }) {
    return FamilyRosterDto(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      memberCount: memberCount ?? this.memberCount,
      publishedCount: publishedCount ?? this.publishedCount,
      deletedAt: deletedAt is _isc.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}

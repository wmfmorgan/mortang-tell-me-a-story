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
import '../membership_role.dart' as _id460rmf;

/// A family the caller belongs to (FamilyEndpoint.listMine).
abstract class MemberFamilyDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  MemberFamilyDto._({
    required this.id,
    required this.name,
    this.parentId,
    this.branchYear,
    required this.createdAt,
    required this.role,
    this.coverKey,
  });

  factory MemberFamilyDto({
    required _is.UuidValue id,
    required String name,
    _is.UuidValue? parentId,
    int? branchYear,
    required DateTime createdAt,
    required _id460rmf.MembershipRole role,
    String? coverKey,
  }) = _MemberFamilyDtoImpl;

  factory MemberFamilyDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return MemberFamilyDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      name: jsonSerialization['name'] as String,
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      branchYear: jsonSerialization['branchYear'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      role: _id460rmf.MembershipRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      coverKey: jsonSerialization['coverKey'] as String?,
    );
  }

  _is.UuidValue id;

  String name;

  _is.UuidValue? parentId;

  int? branchYear;

  DateTime createdAt;

  _id460rmf.MembershipRole role;

  String? coverKey;

  /// Returns a shallow copy of this [MemberFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MemberFamilyDto copyWith({
    _is.UuidValue? id,
    String? name,
    _is.UuidValue? parentId = const _is.$UndefinedUuidValue(),
    int? branchYear,
    DateTime? createdAt,
    _id460rmf.MembershipRole? role,
    String? coverKey,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MemberFamilyDto',
      'id': id.toJson(),
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (branchYear != null) 'branchYear': branchYear,
      'createdAt': createdAt.toJson(),
      'role': role.toJson(),
      if (coverKey != null) 'coverKey': coverKey,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MemberFamilyDto',
      'id': id.toJson(),
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (branchYear != null) 'branchYear': branchYear,
      'createdAt': createdAt.toJson(),
      'role': role.toJson(),
      if (coverKey != null) 'coverKey': coverKey,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MemberFamilyDtoImpl extends MemberFamilyDto {
  _MemberFamilyDtoImpl({
    required _is.UuidValue id,
    required String name,
    _is.UuidValue? parentId,
    int? branchYear,
    required DateTime createdAt,
    required _id460rmf.MembershipRole role,
    String? coverKey,
  }) : super._(
         id: id,
         name: name,
         parentId: parentId,
         branchYear: branchYear,
         createdAt: createdAt,
         role: role,
         coverKey: coverKey,
       );

  /// Returns a shallow copy of this [MemberFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MemberFamilyDto copyWith({
    _is.UuidValue? id,
    String? name,
    _is.UuidValue? parentId = const _is.$UndefinedUuidValue(),
    Object? branchYear = _Undefined,
    DateTime? createdAt,
    _id460rmf.MembershipRole? role,
    Object? coverKey = _Undefined,
  }) {
    return MemberFamilyDto(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId is _is.UndefinedSentinel ? this.parentId : parentId,
      branchYear: branchYear is int? ? branchYear : this.branchYear,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      coverKey: coverKey is String? ? coverKey : this.coverKey,
    );
  }
}

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

/// A family the caller stewards, including soft-deleted ones still inside the 60-day window.
abstract class StewardFamilyDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StewardFamilyDto._({
    required this.id,
    required this.name,
    required this.role,
    this.deletedAt,
  });

  factory StewardFamilyDto({
    required _is.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole role,
    DateTime? deletedAt,
  }) = _StewardFamilyDtoImpl;

  factory StewardFamilyDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StewardFamilyDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      name: jsonSerialization['name'] as String,
      role: _id460rmf.MembershipRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  _is.UuidValue id;

  String name;

  _id460rmf.MembershipRole role;

  DateTime? deletedAt;

  /// Returns a shallow copy of this [StewardFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StewardFamilyDto copyWith({
    _is.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? role,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StewardFamilyDto',
      'id': id.toJson(),
      'name': name,
      'role': role.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StewardFamilyDto',
      'id': id.toJson(),
      'name': name,
      'role': role.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StewardFamilyDtoImpl extends StewardFamilyDto {
  _StewardFamilyDtoImpl({
    required _is.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole role,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         name: name,
         role: role,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [StewardFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StewardFamilyDto copyWith({
    _is.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? role,
    DateTime? deletedAt = const _is.$UndefinedDateTime(),
  }) {
    return StewardFamilyDto(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      deletedAt: deletedAt is _is.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}

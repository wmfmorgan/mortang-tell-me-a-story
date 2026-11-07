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

/// A family the caller stewards, including soft-deleted ones still inside the 60-day window.
abstract class StewardFamilyDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StewardFamilyDto._({
    required this.id,
    required this.name,
    required this.role,
    this.deletedAt,
  });

  factory StewardFamilyDto({
    required _isc.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole role,
    DateTime? deletedAt,
  }) = _StewardFamilyDtoImpl;

  factory StewardFamilyDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StewardFamilyDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      name: jsonSerialization['name'] as String,
      role: _id460rmf.MembershipRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  _isc.UuidValue id;

  String name;

  _id460rmf.MembershipRole role;

  DateTime? deletedAt;

  /// Returns a shallow copy of this [StewardFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StewardFamilyDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? role,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
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
    return _isc.SerializationManager.encode(this);
  }
}

class _StewardFamilyDtoImpl extends StewardFamilyDto {
  _StewardFamilyDtoImpl({
    required _isc.UuidValue id,
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
  @_isc.useResult
  @override
  StewardFamilyDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? role,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  }) {
    return StewardFamilyDto(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      deletedAt: deletedAt is _isc.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}

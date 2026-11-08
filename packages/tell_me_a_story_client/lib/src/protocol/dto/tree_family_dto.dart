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

/// A live family in the caller's tree (FamilyEndpoint.listTree).
abstract class TreeFamilyDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  TreeFamilyDto._({
    required this.id,
    required this.name,
    this.parentId,
    this.branchYear,
    this.effectiveOriginStoryId,
  });

  factory TreeFamilyDto({
    required _isc.UuidValue id,
    required String name,
    _isc.UuidValue? parentId,
    int? branchYear,
    _isc.UuidValue? effectiveOriginStoryId,
  }) = _TreeFamilyDtoImpl;

  factory TreeFamilyDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return TreeFamilyDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      name: jsonSerialization['name'] as String,
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      branchYear: jsonSerialization['branchYear'] as int?,
      effectiveOriginStoryId:
          jsonSerialization['effectiveOriginStoryId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['effectiveOriginStoryId'],
            ),
    );
  }

  _isc.UuidValue id;

  String name;

  _isc.UuidValue? parentId;

  int? branchYear;

  /// Derived, schema-design.md §3.5.
  _isc.UuidValue? effectiveOriginStoryId;

  /// Returns a shallow copy of this [TreeFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  TreeFamilyDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _isc.UuidValue? parentId = const _isc.$UndefinedUuidValue(),
    int? branchYear,
    _isc.UuidValue? effectiveOriginStoryId = const _isc.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TreeFamilyDto',
      'id': id.toJson(),
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (branchYear != null) 'branchYear': branchYear,
      if (effectiveOriginStoryId != null)
        'effectiveOriginStoryId': effectiveOriginStoryId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'TreeFamilyDto',
      'id': id.toJson(),
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (branchYear != null) 'branchYear': branchYear,
      if (effectiveOriginStoryId != null)
        'effectiveOriginStoryId': effectiveOriginStoryId?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TreeFamilyDtoImpl extends TreeFamilyDto {
  _TreeFamilyDtoImpl({
    required _isc.UuidValue id,
    required String name,
    _isc.UuidValue? parentId,
    int? branchYear,
    _isc.UuidValue? effectiveOriginStoryId,
  }) : super._(
         id: id,
         name: name,
         parentId: parentId,
         branchYear: branchYear,
         effectiveOriginStoryId: effectiveOriginStoryId,
       );

  /// Returns a shallow copy of this [TreeFamilyDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  TreeFamilyDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _isc.UuidValue? parentId = const _isc.$UndefinedUuidValue(),
    Object? branchYear = _Undefined,
    _isc.UuidValue? effectiveOriginStoryId = const _isc.$UndefinedUuidValue(),
  }) {
    return TreeFamilyDto(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId is _isc.UndefinedSentinel ? this.parentId : parentId,
      branchYear: branchYear is int? ? branchYear : this.branchYear,
      effectiveOriginStoryId: effectiveOriginStoryId is _isc.UndefinedSentinel
          ? this.effectiveOriginStoryId
          : effectiveOriginStoryId,
    );
  }
}

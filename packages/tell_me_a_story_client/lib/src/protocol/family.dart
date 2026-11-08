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

abstract class Family
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Family._({
    this.id,
    required this.treeId,
    this.parentId,
    required this.name,
    this.branchYear,
    this.originStoryId,
    this.coverKey,
    this.createdById,
    DateTime? createdAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Family({
    _isc.UuidValue? id,
    required _isc.UuidValue treeId,
    _isc.UuidValue? parentId,
    required String name,
    int? branchYear,
    _isc.UuidValue? originStoryId,
    String? coverKey,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) = _FamilyImpl;

  factory Family.fromJson(Map<String, dynamic> jsonSerialization) {
    return Family(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      name: jsonSerialization['name'] as String,
      branchYear: jsonSerialization['branchYear'] as int?,
      originStoryId: jsonSerialization['originStoryId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['originStoryId'],
            ),
      coverKey: jsonSerialization['coverKey'] as String?,
      createdById: jsonSerialization['createdById'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['createdById'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  /// Immutable. Tree rows are deleted by the purge job only when empty.
  _isc.UuidValue treeId;

  /// Branch parent; same tree enforced by raw FK families_parent_same_tree_fk.
  _isc.UuidValue? parentId;

  String name;

  /// Attach year, 1000..9999 (CHECK families_branch_year_1000_9999). Null for roots.
  int? branchYear;

  /// Origin story: published, in the parent family (branch) or this family (root). Set at branch creation, changeable by stewards (setOrigin). Same tree enforced by families_origin_tree_fk; the effective origin is derived (§3.5).
  _isc.UuidValue? originStoryId;

  /// Blob key, see §4. families/{familyId}/cover/{blobId}.{jpg|png|webp}
  String? coverKey;

  _isc.UuidValue? createdById;

  DateTime createdAt;

  /// Soft delete; purged 60 days later by a future call.
  DateTime? deletedAt;

  /// Returns a shallow copy of this [Family]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Family copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? treeId,
    _isc.UuidValue? parentId = const _isc.$UndefinedUuidValue(),
    String? name,
    int? branchYear,
    _isc.UuidValue? originStoryId = const _isc.$UndefinedUuidValue(),
    String? coverKey,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Family',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      'name': name,
      if (branchYear != null) 'branchYear': branchYear,
      if (originStoryId != null) 'originStoryId': originStoryId?.toJson(),
      if (coverKey != null) 'coverKey': coverKey,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Family',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      'name': name,
      if (branchYear != null) 'branchYear': branchYear,
      if (originStoryId != null) 'originStoryId': originStoryId?.toJson(),
      if (coverKey != null) 'coverKey': coverKey,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FamilyImpl extends Family {
  _FamilyImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue treeId,
    _isc.UuidValue? parentId,
    required String name,
    int? branchYear,
    _isc.UuidValue? originStoryId,
    String? coverKey,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         treeId: treeId,
         parentId: parentId,
         name: name,
         branchYear: branchYear,
         originStoryId: originStoryId,
         coverKey: coverKey,
         createdById: createdById,
         createdAt: createdAt,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [Family]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Family copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? treeId,
    _isc.UuidValue? parentId = const _isc.$UndefinedUuidValue(),
    String? name,
    Object? branchYear = _Undefined,
    _isc.UuidValue? originStoryId = const _isc.$UndefinedUuidValue(),
    Object? coverKey = _Undefined,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? deletedAt = const _isc.$UndefinedDateTime(),
  }) {
    return Family(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      parentId: parentId is _isc.UndefinedSentinel ? this.parentId : parentId,
      name: name ?? this.name,
      branchYear: branchYear is int? ? branchYear : this.branchYear,
      originStoryId: originStoryId is _isc.UndefinedSentinel
          ? this.originStoryId
          : originStoryId,
      coverKey: coverKey is String? ? coverKey : this.coverKey,
      createdById: createdById is _isc.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt is _isc.UndefinedSentinel
          ? this.deletedAt
          : deletedAt,
    );
  }
}

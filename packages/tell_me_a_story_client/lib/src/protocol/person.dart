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

abstract class Person
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Person._({
    this.id,
    required this.familyId,
    required this.treeId,
    this.userId,
    required this.name,
    this.relationship,
    this.email,
    this.about,
    this.avatarKey,
    bool? passedAway,
    this.createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : passedAway = passedAway ?? false,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Person({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    required _isc.UuidValue treeId,
    _isc.UuidValue? userId,
    required String name,
    String? relationship,
    String? email,
    String? about,
    String? avatarKey,
    bool? passedAway,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _PersonImpl;

  factory Person.fromJson(Map<String, dynamic> jsonSerialization) {
    return Person(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      treeId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      userId: jsonSerialization['userId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      name: jsonSerialization['name'] as String,
      relationship: jsonSerialization['relationship'] as String?,
      email: jsonSerialization['email'] as String?,
      about: jsonSerialization['about'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      passedAway: jsonSerialization['passedAway'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['passedAway']),
      createdById: jsonSerialization['createdById'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['createdById'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  _isc.UuidValue familyId;

  /// Copy of families.treeId (immutable); kept equal by raw composite FK
  /// people_family_tree_fk. Exists so "one linked person per tree" is a plain unique index.
  _isc.UuidValue treeId;

  /// Linked account. Unique per tree; NULLs are distinct so unlinked people don't collide.
  _isc.UuidValue? userId;

  /// For linked people this mirrors AppUser.displayName (app-layer sync, §3.2).
  String name;

  String? relationship;

  /// Lower-cased, trimmed, non-empty or null (CHECK).
  String? email;

  /// ≤ 500 chars (CHECK).
  String? about;

  /// Blob key, see §4. families/{familyId}/people/{personId}/avatar/{blobId}.jpg
  String? avatarKey;

  bool passedAway;

  _isc.UuidValue? createdById;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Person copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    _isc.UuidValue? treeId,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
    String? name,
    String? relationship,
    String? email,
    String? about,
    String? avatarKey,
    bool? passedAway,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Person',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      'treeId': treeId.toJson(),
      if (userId != null) 'userId': userId?.toJson(),
      'name': name,
      if (relationship != null) 'relationship': relationship,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      'passedAway': passedAway,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Person',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      'treeId': treeId.toJson(),
      if (userId != null) 'userId': userId?.toJson(),
      'name': name,
      if (relationship != null) 'relationship': relationship,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      'passedAway': passedAway,
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonImpl extends Person {
  _PersonImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    required _isc.UuidValue treeId,
    _isc.UuidValue? userId,
    required String name,
    String? relationship,
    String? email,
    String? about,
    String? avatarKey,
    bool? passedAway,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         familyId: familyId,
         treeId: treeId,
         userId: userId,
         name: name,
         relationship: relationship,
         email: email,
         about: about,
         avatarKey: avatarKey,
         passedAway: passedAway,
         createdById: createdById,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Person copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    _isc.UuidValue? treeId,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
    String? name,
    Object? relationship = _Undefined,
    Object? email = _Undefined,
    Object? about = _Undefined,
    Object? avatarKey = _Undefined,
    bool? passedAway,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      familyId: familyId ?? this.familyId,
      treeId: treeId ?? this.treeId,
      userId: userId is _isc.UndefinedSentinel ? this.userId : userId,
      name: name ?? this.name,
      relationship: relationship is String? ? relationship : this.relationship,
      email: email is String? ? email : this.email,
      about: about is String? ? about : this.about,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      passedAway: passedAway ?? this.passedAway,
      createdById: createdById is _isc.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

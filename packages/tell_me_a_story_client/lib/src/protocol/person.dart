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
import 'date_precision.dart' as _ilvyd2nu;

/// A human in one tree, shared by every family (timeline) in the tree.
abstract class Person
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Person._({
    this.id,
    required this.treeId,
    required this.homeFamilyId,
    this.userId,
    required this.name,
    this.email,
    this.about,
    this.avatarKey,
    this.birthDate,
    this.birthPrecision,
    this.deathDate,
    this.deathPrecision,
    bool? passedAway,
    this.createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : passedAway = passedAway ?? false,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Person({
    _isc.UuidValue? id,
    required _isc.UuidValue treeId,
    required _isc.UuidValue homeFamilyId,
    _isc.UuidValue? userId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    DateTime? birthDate,
    _ilvyd2nu.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _ilvyd2nu.DatePrecision? deathPrecision,
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
      treeId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      homeFamilyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['homeFamilyId'],
      ),
      userId: jsonSerialization['userId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      name: jsonSerialization['name'] as String,
      email: jsonSerialization['email'] as String?,
      about: jsonSerialization['about'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      deathDate: jsonSerialization['deathDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deathDate']),
      deathPrecision: jsonSerialization['deathPrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['deathPrecision'] as int),
            ),
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

  /// Owning tree. Deleted with the tree, or explicitly.
  _isc.UuidValue treeId;

  /// Family the person was added in; its stewards hold steward-only rights.
  /// Same tree enforced by people_home_family_tree_fk. The purge job reassigns it before deleting the family (§4.3).
  _isc.UuidValue homeFamilyId;

  /// Linked account. Unique per tree; NULLs are distinct.
  _isc.UuidValue? userId;

  /// For linked people this mirrors AppUser.displayName (app-layer sync, §3.2).
  String name;

  /// Lower-cased, trimmed, non-empty or null (CHECK).
  String? email;

  /// ≤ 500 chars (CHECK).
  String? about;

  /// Blob key, see §4. trees/{treeId}/people/{personId}/avatar/{blobId}.jpg
  String? avatarKey;

  /// UTC midnight aligned to precision (CHECK people_birth_shape). While linked, AppUser birth wins on read.
  DateTime? birthDate;

  _ilvyd2nu.DatePrecision? birthPrecision;

  /// UTC midnight aligned to precision (CHECK people_death_shape). Requires passedAway.
  DateTime? deathDate;

  _ilvyd2nu.DatePrecision? deathPrecision;

  bool passedAway;

  _isc.UuidValue? createdById;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Person copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? treeId,
    _isc.UuidValue? homeFamilyId,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
    String? name,
    String? email,
    String? about,
    String? avatarKey,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? birthPrecision,
    DateTime? deathDate = const _isc.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? deathPrecision,
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
      'treeId': treeId.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      if (userId != null) 'userId': userId?.toJson(),
      'name': name,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
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
      'treeId': treeId.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      if (userId != null) 'userId': userId?.toJson(),
      'name': name,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
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
    required _isc.UuidValue treeId,
    required _isc.UuidValue homeFamilyId,
    _isc.UuidValue? userId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    DateTime? birthDate,
    _ilvyd2nu.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _ilvyd2nu.DatePrecision? deathPrecision,
    bool? passedAway,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         treeId: treeId,
         homeFamilyId: homeFamilyId,
         userId: userId,
         name: name,
         email: email,
         about: about,
         avatarKey: avatarKey,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         deathDate: deathDate,
         deathPrecision: deathPrecision,
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
    _isc.UuidValue? treeId,
    _isc.UuidValue? homeFamilyId,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
    String? name,
    Object? email = _Undefined,
    Object? about = _Undefined,
    Object? avatarKey = _Undefined,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    DateTime? deathDate = const _isc.$UndefinedDateTime(),
    Object? deathPrecision = _Undefined,
    bool? passedAway,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      homeFamilyId: homeFamilyId ?? this.homeFamilyId,
      userId: userId is _isc.UndefinedSentinel ? this.userId : userId,
      name: name ?? this.name,
      email: email is String? ? email : this.email,
      about: about is String? ? about : this.about,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      birthDate: birthDate is _isc.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _ilvyd2nu.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      deathDate: deathDate is _isc.UndefinedSentinel
          ? this.deathDate
          : deathDate,
      deathPrecision: deathPrecision is _ilvyd2nu.DatePrecision?
          ? deathPrecision
          : this.deathPrecision,
      passedAway: passedAway ?? this.passedAway,
      createdById: createdById is _isc.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

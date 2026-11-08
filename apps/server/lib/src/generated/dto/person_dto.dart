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
import '../date_precision.dart' as _irl0sv7o;

/// A person in the tree. Birth comes from the linked AppUser (coarsened by birthVisibility) when linked, else from the person row.
abstract class PersonDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PersonDto._({
    required this.id,
    required this.treeId,
    required this.homeFamilyId,
    required this.name,
    this.email,
    this.about,
    this.avatarKey,
    this.userId,
    required this.passedAway,
    this.birthDate,
    this.birthPrecision,
    this.deathDate,
    this.deathPrecision,
  });

  factory PersonDto({
    required _is.UuidValue id,
    required _is.UuidValue treeId,
    required _is.UuidValue homeFamilyId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    _is.UuidValue? userId,
    required bool passedAway,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
  }) = _PersonDtoImpl;

  factory PersonDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      homeFamilyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['homeFamilyId'],
      ),
      name: jsonSerialization['name'] as String,
      email: jsonSerialization['email'] as String?,
      about: jsonSerialization['about'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      userId: jsonSerialization['userId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      passedAway: _is.BoolJsonExtension.fromJson(
        jsonSerialization['passedAway'],
      ),
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      deathDate: jsonSerialization['deathDate'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deathDate']),
      deathPrecision: jsonSerialization['deathPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['deathPrecision'] as int),
            ),
    );
  }

  _is.UuidValue id;

  _is.UuidValue treeId;

  _is.UuidValue homeFamilyId;

  String name;

  String? email;

  String? about;

  String? avatarKey;

  _is.UuidValue? userId;

  bool passedAway;

  DateTime? birthDate;

  _irl0sv7o.DatePrecision? birthPrecision;

  DateTime? deathDate;

  _irl0sv7o.DatePrecision? deathPrecision;

  /// Returns a shallow copy of this [PersonDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PersonDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? treeId,
    _is.UuidValue? homeFamilyId,
    String? name,
    String? email,
    String? about,
    String? avatarKey,
    _is.UuidValue? userId = const _is.$UndefinedUuidValue(),
    bool? passedAway,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate = const _is.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? deathPrecision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PersonDto',
      'id': id.toJson(),
      'treeId': treeId.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      'name': name,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (userId != null) 'userId': userId?.toJson(),
      'passedAway': passedAway,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PersonDto',
      'id': id.toJson(),
      'treeId': treeId.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      'name': name,
      if (email != null) 'email': email,
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (userId != null) 'userId': userId?.toJson(),
      'passedAway': passedAway,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonDtoImpl extends PersonDto {
  _PersonDtoImpl({
    required _is.UuidValue id,
    required _is.UuidValue treeId,
    required _is.UuidValue homeFamilyId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    _is.UuidValue? userId,
    required bool passedAway,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
  }) : super._(
         id: id,
         treeId: treeId,
         homeFamilyId: homeFamilyId,
         name: name,
         email: email,
         about: about,
         avatarKey: avatarKey,
         userId: userId,
         passedAway: passedAway,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         deathDate: deathDate,
         deathPrecision: deathPrecision,
       );

  /// Returns a shallow copy of this [PersonDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PersonDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? treeId,
    _is.UuidValue? homeFamilyId,
    String? name,
    Object? email = _Undefined,
    Object? about = _Undefined,
    Object? avatarKey = _Undefined,
    _is.UuidValue? userId = const _is.$UndefinedUuidValue(),
    bool? passedAway,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    DateTime? deathDate = const _is.$UndefinedDateTime(),
    Object? deathPrecision = _Undefined,
  }) {
    return PersonDto(
      id: id ?? this.id,
      treeId: treeId ?? this.treeId,
      homeFamilyId: homeFamilyId ?? this.homeFamilyId,
      name: name ?? this.name,
      email: email is String? ? email : this.email,
      about: about is String? ? about : this.about,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      userId: userId is _is.UndefinedSentinel ? this.userId : userId,
      passedAway: passedAway ?? this.passedAway,
      birthDate: birthDate is _is.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _irl0sv7o.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      deathDate: deathDate is _is.UndefinedSentinel
          ? this.deathDate
          : deathDate,
      deathPrecision: deathPrecision is _irl0sv7o.DatePrecision?
          ? deathPrecision
          : this.deathPrecision,
    );
  }
}

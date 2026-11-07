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
import '../date_precision.dart' as _irl0sv7o;

/// A person in the tree. Birth comes from the linked AppUser (coarsened by birthVisibility) when linked, else from the person row.
abstract class PersonDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
    required _isc.UuidValue id,
    required _isc.UuidValue treeId,
    required _isc.UuidValue homeFamilyId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    _isc.UuidValue? userId,
    required bool passedAway,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
  }) = _PersonDtoImpl;

  factory PersonDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      homeFamilyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['homeFamilyId'],
      ),
      name: jsonSerialization['name'] as String,
      email: jsonSerialization['email'] as String?,
      about: jsonSerialization['about'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      userId: jsonSerialization['userId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      passedAway: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['passedAway'],
      ),
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      deathDate: jsonSerialization['deathDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deathDate']),
      deathPrecision: jsonSerialization['deathPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['deathPrecision'] as int),
            ),
    );
  }

  _isc.UuidValue id;

  _isc.UuidValue treeId;

  _isc.UuidValue homeFamilyId;

  String name;

  String? email;

  String? about;

  String? avatarKey;

  _isc.UuidValue? userId;

  bool passedAway;

  DateTime? birthDate;

  _irl0sv7o.DatePrecision? birthPrecision;

  DateTime? deathDate;

  _irl0sv7o.DatePrecision? deathPrecision;

  /// Returns a shallow copy of this [PersonDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PersonDto copyWith({
    _isc.UuidValue? id,
    _isc.UuidValue? treeId,
    _isc.UuidValue? homeFamilyId,
    String? name,
    String? email,
    String? about,
    String? avatarKey,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
    bool? passedAway,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate = const _isc.$UndefinedDateTime(),
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
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonDtoImpl extends PersonDto {
  _PersonDtoImpl({
    required _isc.UuidValue id,
    required _isc.UuidValue treeId,
    required _isc.UuidValue homeFamilyId,
    required String name,
    String? email,
    String? about,
    String? avatarKey,
    _isc.UuidValue? userId,
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
  @_isc.useResult
  @override
  PersonDto copyWith({
    _isc.UuidValue? id,
    _isc.UuidValue? treeId,
    _isc.UuidValue? homeFamilyId,
    String? name,
    Object? email = _Undefined,
    Object? about = _Undefined,
    Object? avatarKey = _Undefined,
    _isc.UuidValue? userId = const _isc.$UndefinedUuidValue(),
    bool? passedAway,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    DateTime? deathDate = const _isc.$UndefinedDateTime(),
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
      userId: userId is _isc.UndefinedSentinel ? this.userId : userId,
      passedAway: passedAway ?? this.passedAway,
      birthDate: birthDate is _isc.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _irl0sv7o.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      deathDate: deathDate is _isc.UndefinedSentinel
          ? this.deathDate
          : deathDate,
      deathPrecision: deathPrecision is _irl0sv7o.DatePrecision?
          ? deathPrecision
          : this.deathPrecision,
    );
  }
}

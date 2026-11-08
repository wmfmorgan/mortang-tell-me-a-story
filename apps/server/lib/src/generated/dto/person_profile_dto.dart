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

/// The person profile dialog. Never carries userId or email.
abstract class PersonProfileDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PersonProfileDto._({
    required this.id,
    required this.homeFamilyId,
    required this.name,
    required this.isLinked,
    this.birthDate,
    this.birthPrecision,
    this.deathDate,
    this.deathPrecision,
    this.about,
    this.avatarKey,
    required this.passedAway,
  });

  factory PersonProfileDto({
    required _is.UuidValue id,
    required _is.UuidValue homeFamilyId,
    required String name,
    required bool isLinked,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
    String? about,
    String? avatarKey,
    required bool passedAway,
  }) = _PersonProfileDtoImpl;

  factory PersonProfileDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonProfileDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      homeFamilyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['homeFamilyId'],
      ),
      name: jsonSerialization['name'] as String,
      isLinked: _is.BoolJsonExtension.fromJson(jsonSerialization['isLinked']),
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
      about: jsonSerialization['about'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      passedAway: _is.BoolJsonExtension.fromJson(
        jsonSerialization['passedAway'],
      ),
    );
  }

  _is.UuidValue id;

  _is.UuidValue homeFamilyId;

  String name;

  bool isLinked;

  DateTime? birthDate;

  _irl0sv7o.DatePrecision? birthPrecision;

  DateTime? deathDate;

  _irl0sv7o.DatePrecision? deathPrecision;

  String? about;

  String? avatarKey;

  bool passedAway;

  /// Returns a shallow copy of this [PersonProfileDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PersonProfileDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? homeFamilyId,
    String? name,
    bool? isLinked,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate = const _is.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? deathPrecision,
    String? about,
    String? avatarKey,
    bool? passedAway,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PersonProfileDto',
      'id': id.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      'name': name,
      'isLinked': isLinked,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      'passedAway': passedAway,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PersonProfileDto',
      'id': id.toJson(),
      'homeFamilyId': homeFamilyId.toJson(),
      'name': name,
      'isLinked': isLinked,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
      if (about != null) 'about': about,
      if (avatarKey != null) 'avatarKey': avatarKey,
      'passedAway': passedAway,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonProfileDtoImpl extends PersonProfileDto {
  _PersonProfileDtoImpl({
    required _is.UuidValue id,
    required _is.UuidValue homeFamilyId,
    required String name,
    required bool isLinked,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
    String? about,
    String? avatarKey,
    required bool passedAway,
  }) : super._(
         id: id,
         homeFamilyId: homeFamilyId,
         name: name,
         isLinked: isLinked,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         deathDate: deathDate,
         deathPrecision: deathPrecision,
         about: about,
         avatarKey: avatarKey,
         passedAway: passedAway,
       );

  /// Returns a shallow copy of this [PersonProfileDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PersonProfileDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? homeFamilyId,
    String? name,
    bool? isLinked,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    DateTime? deathDate = const _is.$UndefinedDateTime(),
    Object? deathPrecision = _Undefined,
    Object? about = _Undefined,
    Object? avatarKey = _Undefined,
    bool? passedAway,
  }) {
    return PersonProfileDto(
      id: id ?? this.id,
      homeFamilyId: homeFamilyId ?? this.homeFamilyId,
      name: name ?? this.name,
      isLinked: isLinked ?? this.isLinked,
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
      about: about is String? ? about : this.about,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      passedAway: passedAway ?? this.passedAway,
    );
  }
}

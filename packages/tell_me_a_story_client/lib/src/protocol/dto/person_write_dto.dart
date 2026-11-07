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

/// Person create/update input. Each write* flag says whether its field group is written.
abstract class PersonWriteDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PersonWriteDto._({
    required this.name,
    this.about,
    required this.writeAbout,
    this.email,
    required this.writeEmail,
    this.passedAway,
    required this.writePassedAway,
    required this.clearPicture,
    this.birthDate,
    this.birthPrecision,
    required this.writeBirth,
    this.deathDate,
    this.deathPrecision,
    required this.writeDeath,
  });

  factory PersonWriteDto({
    required String name,
    String? about,
    required bool writeAbout,
    String? email,
    required bool writeEmail,
    bool? passedAway,
    required bool writePassedAway,
    required bool clearPicture,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    required bool writeBirth,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
    required bool writeDeath,
  }) = _PersonWriteDtoImpl;

  factory PersonWriteDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonWriteDto(
      name: jsonSerialization['name'] as String,
      about: jsonSerialization['about'] as String?,
      writeAbout: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['writeAbout'],
      ),
      email: jsonSerialization['email'] as String?,
      writeEmail: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['writeEmail'],
      ),
      passedAway: jsonSerialization['passedAway'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['passedAway']),
      writePassedAway: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['writePassedAway'],
      ),
      clearPicture: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['clearPicture'],
      ),
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      writeBirth: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['writeBirth'],
      ),
      deathDate: jsonSerialization['deathDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['deathDate']),
      deathPrecision: jsonSerialization['deathPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['deathPrecision'] as int),
            ),
      writeDeath: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['writeDeath'],
      ),
    );
  }

  String name;

  String? about;

  bool writeAbout;

  String? email;

  bool writeEmail;

  bool? passedAway;

  bool writePassedAway;

  bool clearPicture;

  DateTime? birthDate;

  _irl0sv7o.DatePrecision? birthPrecision;

  bool writeBirth;

  DateTime? deathDate;

  _irl0sv7o.DatePrecision? deathPrecision;

  bool writeDeath;

  /// Returns a shallow copy of this [PersonWriteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PersonWriteDto copyWith({
    String? name,
    String? about,
    bool? writeAbout,
    String? email,
    bool? writeEmail,
    bool? passedAway,
    bool? writePassedAway,
    bool? clearPicture,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? birthPrecision,
    bool? writeBirth,
    DateTime? deathDate = const _isc.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? deathPrecision,
    bool? writeDeath,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PersonWriteDto',
      'name': name,
      if (about != null) 'about': about,
      'writeAbout': writeAbout,
      if (email != null) 'email': email,
      'writeEmail': writeEmail,
      if (passedAway != null) 'passedAway': passedAway,
      'writePassedAway': writePassedAway,
      'clearPicture': clearPicture,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      'writeBirth': writeBirth,
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
      'writeDeath': writeDeath,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PersonWriteDto',
      'name': name,
      if (about != null) 'about': about,
      'writeAbout': writeAbout,
      if (email != null) 'email': email,
      'writeEmail': writeEmail,
      if (passedAway != null) 'passedAway': passedAway,
      'writePassedAway': writePassedAway,
      'clearPicture': clearPicture,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      'writeBirth': writeBirth,
      if (deathDate != null) 'deathDate': deathDate?.toJson(),
      if (deathPrecision != null) 'deathPrecision': deathPrecision?.toJson(),
      'writeDeath': writeDeath,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonWriteDtoImpl extends PersonWriteDto {
  _PersonWriteDtoImpl({
    required String name,
    String? about,
    required bool writeAbout,
    String? email,
    required bool writeEmail,
    bool? passedAway,
    required bool writePassedAway,
    required bool clearPicture,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    required bool writeBirth,
    DateTime? deathDate,
    _irl0sv7o.DatePrecision? deathPrecision,
    required bool writeDeath,
  }) : super._(
         name: name,
         about: about,
         writeAbout: writeAbout,
         email: email,
         writeEmail: writeEmail,
         passedAway: passedAway,
         writePassedAway: writePassedAway,
         clearPicture: clearPicture,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         writeBirth: writeBirth,
         deathDate: deathDate,
         deathPrecision: deathPrecision,
         writeDeath: writeDeath,
       );

  /// Returns a shallow copy of this [PersonWriteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PersonWriteDto copyWith({
    String? name,
    Object? about = _Undefined,
    bool? writeAbout,
    Object? email = _Undefined,
    bool? writeEmail,
    Object? passedAway = _Undefined,
    bool? writePassedAway,
    bool? clearPicture,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    bool? writeBirth,
    DateTime? deathDate = const _isc.$UndefinedDateTime(),
    Object? deathPrecision = _Undefined,
    bool? writeDeath,
  }) {
    return PersonWriteDto(
      name: name ?? this.name,
      about: about is String? ? about : this.about,
      writeAbout: writeAbout ?? this.writeAbout,
      email: email is String? ? email : this.email,
      writeEmail: writeEmail ?? this.writeEmail,
      passedAway: passedAway is bool? ? passedAway : this.passedAway,
      writePassedAway: writePassedAway ?? this.writePassedAway,
      clearPicture: clearPicture ?? this.clearPicture,
      birthDate: birthDate is _isc.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _irl0sv7o.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      writeBirth: writeBirth ?? this.writeBirth,
      deathDate: deathDate is _isc.UndefinedSentinel
          ? this.deathDate
          : deathDate,
      deathPrecision: deathPrecision is _irl0sv7o.DatePrecision?
          ? deathPrecision
          : this.deathPrecision,
      writeDeath: writeDeath ?? this.writeDeath,
    );
  }
}

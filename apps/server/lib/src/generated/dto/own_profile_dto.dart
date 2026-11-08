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
import '../birth_visibility.dart' as _iyouxvnq;
import '../date_precision.dart' as _irl0sv7o;

/// The caller's own account (ProfileEndpoint.me). email is read-only (D1).
abstract class OwnProfileDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  OwnProfileDto._({
    required this.authUserId,
    this.displayName,
    this.email,
    this.avatarKey,
    this.birthDate,
    this.birthPrecision,
    required this.birthVisibility,
    this.about,
  });

  factory OwnProfileDto({
    required _is.UuidValue authUserId,
    String? displayName,
    String? email,
    String? avatarKey,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    required _iyouxvnq.BirthVisibility birthVisibility,
    String? about,
  }) = _OwnProfileDtoImpl;

  factory OwnProfileDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return OwnProfileDto(
      authUserId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['authUserId'],
      ),
      displayName: jsonSerialization['displayName'] as String?,
      email: jsonSerialization['email'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      birthVisibility: _iyouxvnq.BirthVisibility.fromJson(
        (jsonSerialization['birthVisibility'] as String),
      ),
      about: jsonSerialization['about'] as String?,
    );
  }

  _is.UuidValue authUserId;

  String? displayName;

  String? email;

  String? avatarKey;

  DateTime? birthDate;

  _irl0sv7o.DatePrecision? birthPrecision;

  _iyouxvnq.BirthVisibility birthVisibility;

  String? about;

  /// Returns a shallow copy of this [OwnProfileDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  OwnProfileDto copyWith({
    _is.UuidValue? authUserId,
    String? displayName,
    String? email,
    String? avatarKey,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? birthPrecision,
    _iyouxvnq.BirthVisibility? birthVisibility,
    String? about,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OwnProfileDto',
      'authUserId': authUserId.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      'birthVisibility': birthVisibility.toJson(),
      if (about != null) 'about': about,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'OwnProfileDto',
      'authUserId': authUserId.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      'birthVisibility': birthVisibility.toJson(),
      if (about != null) 'about': about,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OwnProfileDtoImpl extends OwnProfileDto {
  _OwnProfileDtoImpl({
    required _is.UuidValue authUserId,
    String? displayName,
    String? email,
    String? avatarKey,
    DateTime? birthDate,
    _irl0sv7o.DatePrecision? birthPrecision,
    required _iyouxvnq.BirthVisibility birthVisibility,
    String? about,
  }) : super._(
         authUserId: authUserId,
         displayName: displayName,
         email: email,
         avatarKey: avatarKey,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         birthVisibility: birthVisibility,
         about: about,
       );

  /// Returns a shallow copy of this [OwnProfileDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  OwnProfileDto copyWith({
    _is.UuidValue? authUserId,
    Object? displayName = _Undefined,
    Object? email = _Undefined,
    Object? avatarKey = _Undefined,
    DateTime? birthDate = const _is.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    _iyouxvnq.BirthVisibility? birthVisibility,
    Object? about = _Undefined,
  }) {
    return OwnProfileDto(
      authUserId: authUserId ?? this.authUserId,
      displayName: displayName is String? ? displayName : this.displayName,
      email: email is String? ? email : this.email,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      birthDate: birthDate is _is.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _irl0sv7o.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      birthVisibility: birthVisibility ?? this.birthVisibility,
      about: about is String? ? about : this.about,
    );
  }
}

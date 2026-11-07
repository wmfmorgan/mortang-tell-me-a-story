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

import 'birth_visibility.dart' as _i2x3tia5;
import 'date_precision.dart' as _ilvyd2nu;

/// App-owned profile for one Serverpod AuthUser (1:1 bridge).
/// Endpoints return this only for the caller; other users' data goes out via DTOs
/// (e.g. PersonProfile with birth date coarsened by birthVisibility).
abstract class AppUser
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AppUser._({
    this.id,
    required this.authUserId,
    this.displayName,
    this.avatarKey,
    this.about,
    this.birthDate,
    this.birthPrecision,
    _i2x3tia5.BirthVisibility? birthVisibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : birthVisibility = birthVisibility ?? _i2x3tia5.BirthVisibility.hidden,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory AppUser({
    _isc.UuidValue? id,
    required _isc.UuidValue authUserId,
    String? displayName,
    String? avatarKey,
    String? about,
    DateTime? birthDate,
    _ilvyd2nu.DatePrecision? birthPrecision,
    _i2x3tia5.BirthVisibility? birthVisibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _AppUserImpl;

  factory AppUser.fromJson(Map<String, dynamic> jsonSerialization) {
    return AppUser(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      authUserId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['authUserId'],
      ),
      displayName: jsonSerialization['displayName'] as String?,
      avatarKey: jsonSerialization['avatarKey'] as String?,
      about: jsonSerialization['about'] as String?,
      birthDate: jsonSerialization['birthDate'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['birthDate']),
      birthPrecision: jsonSerialization['birthPrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['birthPrecision'] as int),
            ),
      birthVisibility: jsonSerialization['birthVisibility'] == null
          ? null
          : _i2x3tia5.BirthVisibility.fromJson(
              (jsonSerialization['birthVisibility'] as String),
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

  /// serverpod_auth_core_user.id
  _isc.UuidValue authUserId;

  String? displayName;

  /// Blob key, see §4. users/{authUserId}/avatar/{blobId}.jpg
  String? avatarKey;

  /// ≤ 500 chars (CHECK users_about_len).
  String? about;

  /// UTC midnight. Paired with birthPrecision (CHECK users_birth_pair).
  DateTime? birthDate;

  _ilvyd2nu.DatePrecision? birthPrecision;

  _i2x3tia5.BirthVisibility birthVisibility;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [AppUser]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AppUser copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? authUserId,
    String? displayName,
    String? avatarKey,
    String? about,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? birthPrecision,
    _i2x3tia5.BirthVisibility? birthVisibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AppUser',
      if (id != null) 'id': id?.toJson(),
      'authUserId': authUserId.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (about != null) 'about': about,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      'birthVisibility': birthVisibility.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AppUser',
      if (id != null) 'id': id?.toJson(),
      'authUserId': authUserId.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (avatarKey != null) 'avatarKey': avatarKey,
      if (about != null) 'about': about,
      if (birthDate != null) 'birthDate': birthDate?.toJson(),
      if (birthPrecision != null) 'birthPrecision': birthPrecision?.toJson(),
      'birthVisibility': birthVisibility.toJson(),
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

class _AppUserImpl extends AppUser {
  _AppUserImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue authUserId,
    String? displayName,
    String? avatarKey,
    String? about,
    DateTime? birthDate,
    _ilvyd2nu.DatePrecision? birthPrecision,
    _i2x3tia5.BirthVisibility? birthVisibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         authUserId: authUserId,
         displayName: displayName,
         avatarKey: avatarKey,
         about: about,
         birthDate: birthDate,
         birthPrecision: birthPrecision,
         birthVisibility: birthVisibility,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AppUser]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AppUser copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? authUserId,
    Object? displayName = _Undefined,
    Object? avatarKey = _Undefined,
    Object? about = _Undefined,
    DateTime? birthDate = const _isc.$UndefinedDateTime(),
    Object? birthPrecision = _Undefined,
    _i2x3tia5.BirthVisibility? birthVisibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      authUserId: authUserId ?? this.authUserId,
      displayName: displayName is String? ? displayName : this.displayName,
      avatarKey: avatarKey is String? ? avatarKey : this.avatarKey,
      about: about is String? ? about : this.about,
      birthDate: birthDate is _isc.UndefinedSentinel
          ? this.birthDate
          : birthDate,
      birthPrecision: birthPrecision is _ilvyd2nu.DatePrecision?
          ? birthPrecision
          : this.birthPrecision,
      birthVisibility: birthVisibility ?? this.birthVisibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

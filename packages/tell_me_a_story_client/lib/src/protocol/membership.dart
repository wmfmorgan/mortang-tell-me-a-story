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
import 'membership_role.dart' as _iur1rrwm;

abstract class Membership
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Membership._({
    this.id,
    required this.familyId,
    required this.userId,
    _iur1rrwm.MembershipRole? role,
    DateTime? createdAt,
  }) : role = role ?? _iur1rrwm.MembershipRole.member,
       createdAt = createdAt ?? DateTime.now();

  factory Membership({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    required _isc.UuidValue userId,
    _iur1rrwm.MembershipRole? role,
    DateTime? createdAt,
  }) = _MembershipImpl;

  factory Membership.fromJson(Map<String, dynamic> jsonSerialization) {
    return Membership(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      userId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      role: jsonSerialization['role'] == null
          ? null
          : _iur1rrwm.MembershipRole.fromJson(
              (jsonSerialization['role'] as String),
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  _isc.UuidValue familyId;

  _isc.UuidValue userId;

  /// One owner per family: raw partial unique index memberships_one_owner_uidx.
  _iur1rrwm.MembershipRole role;

  DateTime createdAt;

  /// Returns a shallow copy of this [Membership]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Membership copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    _isc.UuidValue? userId,
    _iur1rrwm.MembershipRole? role,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Membership',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      'userId': userId.toJson(),
      'role': role.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Membership',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      'userId': userId.toJson(),
      'role': role.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _MembershipImpl extends Membership {
  _MembershipImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    required _isc.UuidValue userId,
    _iur1rrwm.MembershipRole? role,
    DateTime? createdAt,
  }) : super._(
         id: id,
         familyId: familyId,
         userId: userId,
         role: role,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Membership]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Membership copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    _isc.UuidValue? userId,
    _iur1rrwm.MembershipRole? role,
    DateTime? createdAt,
  }) {
    return Membership(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

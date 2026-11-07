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
import 'kinship_kind.dart' as _iq59nsdl;

/// Person-to-person edge inside one tree. Replaces the dropped free-text people.relationship.
abstract class Kinship
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Kinship._({
    this.id,
    required this.treeId,
    required this.kind,
    required this.fromPersonId,
    required this.toPersonId,
    this.createdById,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Kinship({
    _isc.UuidValue? id,
    required _isc.UuidValue treeId,
    required _iq59nsdl.KinshipKind kind,
    required _isc.UuidValue fromPersonId,
    required _isc.UuidValue toPersonId,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
  }) = _KinshipImpl;

  factory Kinship.fromJson(Map<String, dynamic> jsonSerialization) {
    return Kinship(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      kind: _iq59nsdl.KinshipKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      fromPersonId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['fromPersonId'],
      ),
      toPersonId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['toPersonId'],
      ),
      createdById: jsonSerialization['createdById'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['createdById'],
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

  _isc.UuidValue treeId;

  _iq59nsdl.KinshipKind kind;

  _isc.UuidValue fromPersonId;

  _isc.UuidValue toPersonId;

  _isc.UuidValue? createdById;

  DateTime createdAt;

  /// Returns a shallow copy of this [Kinship]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Kinship copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? treeId,
    _iq59nsdl.KinshipKind? kind,
    _isc.UuidValue? fromPersonId,
    _isc.UuidValue? toPersonId,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Kinship',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'kind': kind.toJson(),
      'fromPersonId': fromPersonId.toJson(),
      'toPersonId': toPersonId.toJson(),
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Kinship',
      if (id != null) 'id': id?.toJson(),
      'treeId': treeId.toJson(),
      'kind': kind.toJson(),
      'fromPersonId': fromPersonId.toJson(),
      'toPersonId': toPersonId.toJson(),
      if (createdById != null) 'createdById': createdById?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _KinshipImpl extends Kinship {
  _KinshipImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue treeId,
    required _iq59nsdl.KinshipKind kind,
    required _isc.UuidValue fromPersonId,
    required _isc.UuidValue toPersonId,
    _isc.UuidValue? createdById,
    DateTime? createdAt,
  }) : super._(
         id: id,
         treeId: treeId,
         kind: kind,
         fromPersonId: fromPersonId,
         toPersonId: toPersonId,
         createdById: createdById,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Kinship]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Kinship copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? treeId,
    _iq59nsdl.KinshipKind? kind,
    _isc.UuidValue? fromPersonId,
    _isc.UuidValue? toPersonId,
    _isc.UuidValue? createdById = const _isc.$UndefinedUuidValue(),
    DateTime? createdAt,
  }) {
    return Kinship(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      treeId: treeId ?? this.treeId,
      kind: kind ?? this.kind,
      fromPersonId: fromPersonId ?? this.fromPersonId,
      toPersonId: toPersonId ?? this.toPersonId,
      createdById: createdById is _isc.UndefinedSentinel
          ? this.createdById
          : createdById,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

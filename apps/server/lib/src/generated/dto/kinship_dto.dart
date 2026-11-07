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
import '../kinship_kind.dart' as _ih4h8pun;

/// A kinship edge (contract only; no client UI yet).
abstract class KinshipDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  KinshipDto._({
    required this.id,
    required this.kind,
    required this.fromPersonId,
    required this.toPersonId,
  });

  factory KinshipDto({
    required _is.UuidValue id,
    required _ih4h8pun.KinshipKind kind,
    required _is.UuidValue fromPersonId,
    required _is.UuidValue toPersonId,
  }) = _KinshipDtoImpl;

  factory KinshipDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return KinshipDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      kind: _ih4h8pun.KinshipKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      fromPersonId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['fromPersonId'],
      ),
      toPersonId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['toPersonId'],
      ),
    );
  }

  _is.UuidValue id;

  _ih4h8pun.KinshipKind kind;

  _is.UuidValue fromPersonId;

  _is.UuidValue toPersonId;

  /// Returns a shallow copy of this [KinshipDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  KinshipDto copyWith({
    _is.UuidValue? id,
    _ih4h8pun.KinshipKind? kind,
    _is.UuidValue? fromPersonId,
    _is.UuidValue? toPersonId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'KinshipDto',
      'id': id.toJson(),
      'kind': kind.toJson(),
      'fromPersonId': fromPersonId.toJson(),
      'toPersonId': toPersonId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'KinshipDto',
      'id': id.toJson(),
      'kind': kind.toJson(),
      'fromPersonId': fromPersonId.toJson(),
      'toPersonId': toPersonId.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _KinshipDtoImpl extends KinshipDto {
  _KinshipDtoImpl({
    required _is.UuidValue id,
    required _ih4h8pun.KinshipKind kind,
    required _is.UuidValue fromPersonId,
    required _is.UuidValue toPersonId,
  }) : super._(
         id: id,
         kind: kind,
         fromPersonId: fromPersonId,
         toPersonId: toPersonId,
       );

  /// Returns a shallow copy of this [KinshipDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  KinshipDto copyWith({
    _is.UuidValue? id,
    _ih4h8pun.KinshipKind? kind,
    _is.UuidValue? fromPersonId,
    _is.UuidValue? toPersonId,
  }) {
    return KinshipDto(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      fromPersonId: fromPersonId ?? this.fromPersonId,
      toPersonId: toPersonId ?? this.toPersonId,
    );
  }
}

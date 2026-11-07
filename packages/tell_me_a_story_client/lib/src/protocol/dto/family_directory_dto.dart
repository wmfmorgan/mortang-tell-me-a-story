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
import 'package:tell_me_a_story_client/src/protocol/protocol.dart' as _ipmlb5v5;
import '../dto/family_roster_dto.dart' as _i2c4pmf8;

/// The caller's families, split into active and recoverable (FamilyEndpoint.directory).
abstract class FamilyDirectoryDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FamilyDirectoryDto._({
    required this.active,
    required this.recoverable,
  });

  factory FamilyDirectoryDto({
    required List<_i2c4pmf8.FamilyRosterDto> active,
    required List<_i2c4pmf8.FamilyRosterDto> recoverable,
  }) = _FamilyDirectoryDtoImpl;

  factory FamilyDirectoryDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return FamilyDirectoryDto(
      active: _ipmlb5v5.Protocol().deserialize<List<_i2c4pmf8.FamilyRosterDto>>(
        jsonSerialization['active'],
      ),
      recoverable: _ipmlb5v5.Protocol()
          .deserialize<List<_i2c4pmf8.FamilyRosterDto>>(
            jsonSerialization['recoverable'],
          ),
    );
  }

  List<_i2c4pmf8.FamilyRosterDto> active;

  List<_i2c4pmf8.FamilyRosterDto> recoverable;

  /// Returns a shallow copy of this [FamilyDirectoryDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FamilyDirectoryDto copyWith({
    List<_i2c4pmf8.FamilyRosterDto>? active,
    List<_i2c4pmf8.FamilyRosterDto>? recoverable,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FamilyDirectoryDto',
      'active': active.toJson(valueToJson: (v) => v.toJson()),
      'recoverable': recoverable.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FamilyDirectoryDto',
      'active': active.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'recoverable': recoverable.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _FamilyDirectoryDtoImpl extends FamilyDirectoryDto {
  _FamilyDirectoryDtoImpl({
    required List<_i2c4pmf8.FamilyRosterDto> active,
    required List<_i2c4pmf8.FamilyRosterDto> recoverable,
  }) : super._(
         active: active,
         recoverable: recoverable,
       );

  /// Returns a shallow copy of this [FamilyDirectoryDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FamilyDirectoryDto copyWith({
    List<_i2c4pmf8.FamilyRosterDto>? active,
    List<_i2c4pmf8.FamilyRosterDto>? recoverable,
  }) {
    return FamilyDirectoryDto(
      active: active ?? this.active.map((e0) => e0.copyWith()).toList(),
      recoverable:
          recoverable ?? this.recoverable.map((e0) => e0.copyWith()).toList(),
    );
  }
}

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

/// A family whose effective origin is a given story.
abstract class OriginDependentDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  OriginDependentDto._({
    required this.familyId,
    required this.name,
  });

  factory OriginDependentDto({
    required _is.UuidValue familyId,
    required String name,
  }) = _OriginDependentDtoImpl;

  factory OriginDependentDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return OriginDependentDto(
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      name: jsonSerialization['name'] as String,
    );
  }

  _is.UuidValue familyId;

  String name;

  /// Returns a shallow copy of this [OriginDependentDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  OriginDependentDto copyWith({
    _is.UuidValue? familyId,
    String? name,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OriginDependentDto',
      'familyId': familyId.toJson(),
      'name': name,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'OriginDependentDto',
      'familyId': familyId.toJson(),
      'name': name,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _OriginDependentDtoImpl extends OriginDependentDto {
  _OriginDependentDtoImpl({
    required _is.UuidValue familyId,
    required String name,
  }) : super._(
         familyId: familyId,
         name: name,
       );

  /// Returns a shallow copy of this [OriginDependentDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  OriginDependentDto copyWith({
    _is.UuidValue? familyId,
    String? name,
  }) {
    return OriginDependentDto(
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
    );
  }
}

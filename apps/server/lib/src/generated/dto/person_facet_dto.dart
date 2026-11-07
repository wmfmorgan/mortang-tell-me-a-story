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

/// Search facet: a tagged person and their story count.
abstract class PersonFacetDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PersonFacetDto._({
    required this.personId,
    required this.name,
    required this.storyCount,
  });

  factory PersonFacetDto({
    required _is.UuidValue personId,
    required String name,
    required int storyCount,
  }) = _PersonFacetDtoImpl;

  factory PersonFacetDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonFacetDto(
      personId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['personId'],
      ),
      name: jsonSerialization['name'] as String,
      storyCount: jsonSerialization['storyCount'] as int,
    );
  }

  _is.UuidValue personId;

  String name;

  int storyCount;

  /// Returns a shallow copy of this [PersonFacetDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PersonFacetDto copyWith({
    _is.UuidValue? personId,
    String? name,
    int? storyCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PersonFacetDto',
      'personId': personId.toJson(),
      'name': name,
      'storyCount': storyCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PersonFacetDto',
      'personId': personId.toJson(),
      'name': name,
      'storyCount': storyCount,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PersonFacetDtoImpl extends PersonFacetDto {
  _PersonFacetDtoImpl({
    required _is.UuidValue personId,
    required String name,
    required int storyCount,
  }) : super._(
         personId: personId,
         name: name,
         storyCount: storyCount,
       );

  /// Returns a shallow copy of this [PersonFacetDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PersonFacetDto copyWith({
    _is.UuidValue? personId,
    String? name,
    int? storyCount,
  }) {
    return PersonFacetDto(
      personId: personId ?? this.personId,
      name: name ?? this.name,
      storyCount: storyCount ?? this.storyCount,
    );
  }
}

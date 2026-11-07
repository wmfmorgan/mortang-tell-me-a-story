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

/// Search facet: a decade and its story count.
abstract class DecadeFacetDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DecadeFacetDto._({
    required this.decade,
    required this.storyCount,
  });

  factory DecadeFacetDto({
    required int decade,
    required int storyCount,
  }) = _DecadeFacetDtoImpl;

  factory DecadeFacetDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return DecadeFacetDto(
      decade: jsonSerialization['decade'] as int,
      storyCount: jsonSerialization['storyCount'] as int,
    );
  }

  int decade;

  int storyCount;

  /// Returns a shallow copy of this [DecadeFacetDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DecadeFacetDto copyWith({
    int? decade,
    int? storyCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DecadeFacetDto',
      'decade': decade,
      'storyCount': storyCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DecadeFacetDto',
      'decade': decade,
      'storyCount': storyCount,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DecadeFacetDtoImpl extends DecadeFacetDto {
  _DecadeFacetDtoImpl({
    required int decade,
    required int storyCount,
  }) : super._(
         decade: decade,
         storyCount: storyCount,
       );

  /// Returns a shallow copy of this [DecadeFacetDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DecadeFacetDto copyWith({
    int? decade,
    int? storyCount,
  }) {
    return DecadeFacetDto(
      decade: decade ?? this.decade,
      storyCount: storyCount ?? this.storyCount,
    );
  }
}

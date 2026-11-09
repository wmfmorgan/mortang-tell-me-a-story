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

/// Search facet: a place and its story count.
abstract class PlaceFacetDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PlaceFacetDto._({
    required this.placeId,
    required this.label,
    required this.storyCount,
  });

  factory PlaceFacetDto({
    required _isc.UuidValue placeId,
    required String label,
    required int storyCount,
  }) = _PlaceFacetDtoImpl;

  factory PlaceFacetDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PlaceFacetDto(
      placeId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['placeId'],
      ),
      label: jsonSerialization['label'] as String,
      storyCount: jsonSerialization['storyCount'] as int,
    );
  }

  _isc.UuidValue placeId;

  String label;

  int storyCount;

  /// Returns a shallow copy of this [PlaceFacetDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PlaceFacetDto copyWith({
    _isc.UuidValue? placeId,
    String? label,
    int? storyCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlaceFacetDto',
      'placeId': placeId.toJson(),
      'label': label,
      'storyCount': storyCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PlaceFacetDto',
      'placeId': placeId.toJson(),
      'label': label,
      'storyCount': storyCount,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PlaceFacetDtoImpl extends PlaceFacetDto {
  _PlaceFacetDtoImpl({
    required _isc.UuidValue placeId,
    required String label,
    required int storyCount,
  }) : super._(
         placeId: placeId,
         label: label,
         storyCount: storyCount,
       );

  /// Returns a shallow copy of this [PlaceFacetDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PlaceFacetDto copyWith({
    _isc.UuidValue? placeId,
    String? label,
    int? storyCount,
  }) {
    return PlaceFacetDto(
      placeId: placeId ?? this.placeId,
      label: label ?? this.label,
      storyCount: storyCount ?? this.storyCount,
    );
  }
}

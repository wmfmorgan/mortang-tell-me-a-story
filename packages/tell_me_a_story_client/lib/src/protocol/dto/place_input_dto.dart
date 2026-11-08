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

/// Place create input.
abstract class PlaceInputDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PlaceInputDto._({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    required this.isFavorite,
  });

  factory PlaceInputDto({
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    required bool isFavorite,
  }) = _PlaceInputDtoImpl;

  factory PlaceInputDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PlaceInputDto(
      label: jsonSerialization['label'] as String,
      address: jsonSerialization['address'] as String,
      lat: (jsonSerialization['lat'] as num).toDouble(),
      lng: (jsonSerialization['lng'] as num).toDouble(),
      mapboxPlaceId: jsonSerialization['mapboxPlaceId'] as String?,
      isFavorite: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['isFavorite'],
      ),
    );
  }

  String label;

  String address;

  double lat;

  double lng;

  String? mapboxPlaceId;

  bool isFavorite;

  /// Returns a shallow copy of this [PlaceInputDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PlaceInputDto copyWith({
    String? label,
    String? address,
    double? lat,
    double? lng,
    String? mapboxPlaceId,
    bool? isFavorite,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlaceInputDto',
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (mapboxPlaceId != null) 'mapboxPlaceId': mapboxPlaceId,
      'isFavorite': isFavorite,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PlaceInputDto',
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (mapboxPlaceId != null) 'mapboxPlaceId': mapboxPlaceId,
      'isFavorite': isFavorite,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlaceInputDtoImpl extends PlaceInputDto {
  _PlaceInputDtoImpl({
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    required bool isFavorite,
  }) : super._(
         label: label,
         address: address,
         lat: lat,
         lng: lng,
         mapboxPlaceId: mapboxPlaceId,
         isFavorite: isFavorite,
       );

  /// Returns a shallow copy of this [PlaceInputDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PlaceInputDto copyWith({
    String? label,
    String? address,
    double? lat,
    double? lng,
    Object? mapboxPlaceId = _Undefined,
    bool? isFavorite,
  }) {
    return PlaceInputDto(
      label: label ?? this.label,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      mapboxPlaceId: mapboxPlaceId is String?
          ? mapboxPlaceId
          : this.mapboxPlaceId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

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

/// A place, shared by every family in the tree.
abstract class PlaceDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PlaceDto._({
    required this.id,
    required this.treeId,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    required this.isFavorite,
    this.lastUsedAt,
  });

  factory PlaceDto({
    required _is.UuidValue id,
    required _is.UuidValue treeId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    required bool isFavorite,
    DateTime? lastUsedAt,
  }) = _PlaceDtoImpl;

  factory PlaceDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PlaceDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      treeId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['treeId']),
      label: jsonSerialization['label'] as String,
      address: jsonSerialization['address'] as String,
      lat: (jsonSerialization['lat'] as num).toDouble(),
      lng: (jsonSerialization['lng'] as num).toDouble(),
      mapboxPlaceId: jsonSerialization['mapboxPlaceId'] as String?,
      isFavorite: _is.BoolJsonExtension.fromJson(
        jsonSerialization['isFavorite'],
      ),
      lastUsedAt: jsonSerialization['lastUsedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastUsedAt']),
    );
  }

  _is.UuidValue id;

  _is.UuidValue treeId;

  String label;

  String address;

  double lat;

  double lng;

  String? mapboxPlaceId;

  bool isFavorite;

  DateTime? lastUsedAt;

  /// Returns a shallow copy of this [PlaceDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PlaceDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? treeId,
    String? label,
    String? address,
    double? lat,
    double? lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlaceDto',
      'id': id.toJson(),
      'treeId': treeId.toJson(),
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (mapboxPlaceId != null) 'mapboxPlaceId': mapboxPlaceId,
      'isFavorite': isFavorite,
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PlaceDto',
      'id': id.toJson(),
      'treeId': treeId.toJson(),
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      if (mapboxPlaceId != null) 'mapboxPlaceId': mapboxPlaceId,
      'isFavorite': isFavorite,
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlaceDtoImpl extends PlaceDto {
  _PlaceDtoImpl({
    required _is.UuidValue id,
    required _is.UuidValue treeId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    required bool isFavorite,
    DateTime? lastUsedAt,
  }) : super._(
         id: id,
         treeId: treeId,
         label: label,
         address: address,
         lat: lat,
         lng: lng,
         mapboxPlaceId: mapboxPlaceId,
         isFavorite: isFavorite,
         lastUsedAt: lastUsedAt,
       );

  /// Returns a shallow copy of this [PlaceDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PlaceDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? treeId,
    String? label,
    String? address,
    double? lat,
    double? lng,
    Object? mapboxPlaceId = _Undefined,
    bool? isFavorite,
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
  }) {
    return PlaceDto(
      id: id ?? this.id,
      treeId: treeId ?? this.treeId,
      label: label ?? this.label,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      mapboxPlaceId: mapboxPlaceId is String?
          ? mapboxPlaceId
          : this.mapboxPlaceId,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsedAt: lastUsedAt is _is.UndefinedSentinel
          ? this.lastUsedAt
          : lastUsedAt,
    );
  }
}

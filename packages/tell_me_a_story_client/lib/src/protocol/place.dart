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

abstract class Place
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Place._({
    this.id,
    required this.familyId,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    bool? isFavorite,
    this.lastUsedAt,
  }) : isFavorite = isFavorite ?? false;

  factory Place({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt,
  }) = _PlaceImpl;

  factory Place.fromJson(Map<String, dynamic> jsonSerialization) {
    return Place(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      label: jsonSerialization['label'] as String,
      address: jsonSerialization['address'] as String,
      lat: (jsonSerialization['lat'] as num).toDouble(),
      lng: (jsonSerialization['lng'] as num).toDouble(),
      mapboxPlaceId: jsonSerialization['mapboxPlaceId'] as String?,
      isFavorite: jsonSerialization['isFavorite'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isFavorite']),
      lastUsedAt: jsonSerialization['lastUsedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastUsedAt'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  _isc.UuidValue familyId;

  String label;

  String address;

  double lat;

  double lng;

  String? mapboxPlaceId;

  bool isFavorite;

  DateTime? lastUsedAt;

  /// Returns a shallow copy of this [Place]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Place copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    String? label,
    String? address,
    double? lat,
    double? lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Place',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
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
      '__className__': 'Place',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
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
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlaceImpl extends Place {
  _PlaceImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool? isFavorite,
    DateTime? lastUsedAt,
  }) : super._(
         id: id,
         familyId: familyId,
         label: label,
         address: address,
         lat: lat,
         lng: lng,
         mapboxPlaceId: mapboxPlaceId,
         isFavorite: isFavorite,
         lastUsedAt: lastUsedAt,
       );

  /// Returns a shallow copy of this [Place]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Place copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    String? label,
    String? address,
    double? lat,
    double? lng,
    Object? mapboxPlaceId = _Undefined,
    bool? isFavorite,
    DateTime? lastUsedAt = const _isc.$UndefinedDateTime(),
  }) {
    return Place(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      familyId: familyId ?? this.familyId,
      label: label ?? this.label,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      mapboxPlaceId: mapboxPlaceId is String?
          ? mapboxPlaceId
          : this.mapboxPlaceId,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsedAt: lastUsedAt is _isc.UndefinedSentinel
          ? this.lastUsedAt
          : lastUsedAt,
    );
  }
}

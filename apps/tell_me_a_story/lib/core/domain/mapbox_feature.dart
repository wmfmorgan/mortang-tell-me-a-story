import 'package:freezed_annotation/freezed_annotation.dart';

part 'mapbox_feature.freezed.dart';
part 'mapbox_feature.g.dart';

/// The fields of one Mapbox Geocoding feature that [MapboxSearchHit] reads.
/// [center] and [geometry] stay loose JSON: a malformed center falls back to
/// the geometry coordinates instead of failing the parse.
@freezed
abstract class MapboxFeature with _$MapboxFeature {
  const factory MapboxFeature({
    required String id,
    String? text,
    @JsonKey(name: 'place_name') String? placeName,
    // JSON boundary: Mapbox sends a list, but fallbacks handle anything.
    Object? center,
    Object? geometry,
  }) = _MapboxFeature;

  factory MapboxFeature.fromJson(Map<String, dynamic> json) =>
      _$MapboxFeatureFromJson(json);
}

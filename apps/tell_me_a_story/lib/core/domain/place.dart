import 'package:freezed_annotation/freezed_annotation.dart';

part 'place.freezed.dart';

/// A place shared by the families of one tree (favorites + recents via
/// [isFavorite] / [lastUsedAt]).
@freezed
abstract class Place with _$Place {
  const factory Place({
    required String id,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    required bool isFavorite,
    DateTime? lastUsedAt,
  }) = _Place;
}

/// Rejects empty / whitespace-only label or address before network.
void ensureValidPlaceCreate({required String label, required String address}) {
  if (label.trim().isEmpty) {
    throw ArgumentError.value(label, 'label', 'must not be empty');
  }
  if (address.trim().isEmpty) {
    throw ArgumentError.value(address, 'address', 'must not be empty');
  }
}

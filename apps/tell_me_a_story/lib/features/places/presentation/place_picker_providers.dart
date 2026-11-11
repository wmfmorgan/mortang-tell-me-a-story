import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';

part 'place_picker_providers.g.dart';

/// Favorites and recents shown by the place picker tabs.
@immutable
class PlacePickerLists {
  const PlacePickerLists({required this.favorites, required this.recents});

  static const empty = PlacePickerLists(favorites: [], recents: []);

  final List<Place> favorites;
  final List<Place> recents;

  @override
  bool operator ==(Object other) =>
      other is PlacePickerLists &&
      listEquals(other.favorites, favorites) &&
      listEquals(other.recents, recents);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(favorites), Object.hashAll(recents));
}

/// Loads the picker's favorites, then recents, for [familyId].
@riverpod
Future<PlacePickerLists> placePickerLists(Ref ref, String familyId) async {
  final places = ref.watch(placesRepositoryProvider);
  final favorites = await places.listFavorites(familyId);
  final recents = await places.listRecents(familyId);
  return PlacePickerLists(favorites: favorites, recents: recents);
}

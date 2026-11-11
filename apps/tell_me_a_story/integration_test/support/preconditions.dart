import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';

/// Signs the carried-over session out and drops the in-memory family and
/// profile held by [container] (the app's).
Future<void> resetAppState(ProviderContainer container) async {
  final auth = serverClient.auth;
  if (auth.isAuthenticated) await auth.signOutDevice();
  container.read(familySelectionProvider.notifier).clear();
  container.read(profileSessionProvider.notifier).clear();
}

/// The family a favorite was created in, and the label the picker shows.
typedef FavoritePlace = ({String familyId, String label});

/// Favorite on the signed-in user's current family. No Mapbox id.
Future<FavoritePlace> createFavoritePlace(
  ProviderContainer container, {
  required String label,
  required String address,
}) async {
  final familyId =
      container.read(familySelectionProvider) ??
      await container.read(inviteRepositoryProvider).currentFamilyId();
  if (familyId == null) {
    throw StateError('no family for favorite place');
  }
  final place = await container
      .read(placesRepositoryProvider)
      .createPlace(
        familyId: familyId,
        label: label,
        address: address,
        lat: 30.2672,
        lng: -97.7431,
        isFavorite: true,
      );
  return (familyId: familyId, label: place.label);
}

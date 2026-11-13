import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';

/// Drops the carried-over session and the in-memory family and profile.
Future<void> resetAppState() async {
  if (Supabase.instance.client.auth.currentSession != null) {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  }
  FamilySelection.clear();
  ProfileSession.instance.clear();
}

/// Favorite on the signed-in user's current family. No Mapbox id.
Future<Place> createFavoritePlace({
  required String label,
  required String address,
}) async {
  final familyId = FamilySelection.id ?? await InviteApi().currentFamilyId();
  if (familyId == null) {
    throw StateError('no family for favorite place');
  }
  return PlacesApi().createPlace(
    familyId: familyId,
    label: label,
    address: address,
    lat: 30.2672,
    lng: -97.7431,
    isFavorite: true,
  );
}

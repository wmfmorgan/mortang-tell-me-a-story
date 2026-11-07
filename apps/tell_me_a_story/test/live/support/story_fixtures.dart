import 'dart:convert';
import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart';

/// A 1×1 PNG, small enough for any photo check the server makes.
final livePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// What [seedFamily] made, as the app's string ids.
typedef SeededFamily = ({String familyId, String personId, String placeId});

/// A root family owned by [client]'s user, with one person and one place,
/// made through the raw client so story tests don't depend on other gateways.
Future<SeededFamily> seedFamily(
  Client client, {
  String person = 'Ada',
  String place = 'Back Porch',
}) async {
  final familyId = await client.family.createRoot('Live stories');
  final personId = await seedPerson(client, familyId.toString(), name: person);
  final placeId = await seedPlace(client, familyId.toString(), label: place);
  return (familyId: familyId.toString(), personId: personId, placeId: placeId);
}

/// One more unlinked person in [familyId].
Future<String> seedPerson(
  Client client,
  String familyId, {
  required String name,
}) async {
  final person = await client.people.create(
    UuidValue.fromString(familyId),
    PersonWriteDto(
      name: name,
      writeAbout: false,
      writeEmail: false,
      writePassedAway: false,
      clearPicture: false,
      writeBirth: false,
      writeDeath: false,
    ),
    null,
  );
  return person.id.toString();
}

/// One more place in [familyId].
Future<String> seedPlace(
  Client client,
  String familyId, {
  required String label,
}) async {
  final place = await client.place.create(
    UuidValue.fromString(familyId),
    PlaceInputDto(
      label: label,
      address: '$label, 12 Lane',
      lat: 1,
      lng: 2,
      isFavorite: false,
    ),
  );
  return place.id.toString();
}

/// Adds [livePng] to [storyId] as its first photo and returns the blob key.
Future<String> seedPhoto(Client client, String storyId) async {
  final story = UuidValue.fromString(storyId);
  final ticket = await client.photo.startUpload(
    story,
    'image/png',
    livePng.length,
  );
  final uploaded = await FileUploader(ticket.uploadDescription)
      .uploadByteData(ByteData.sublistView(livePng));
  if (!uploaded) throw StateError('photo upload failed');
  final photo = await client.photo.finishUpload(story, ticket.photoId, 0);
  return photo.originalKey;
}

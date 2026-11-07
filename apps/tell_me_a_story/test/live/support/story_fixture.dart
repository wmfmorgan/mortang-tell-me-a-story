import 'package:tell_me_a_story_client/tell_me_a_story_client.dart';

/// A fresh root family owned by [owner] with one undated story in it,
/// published when [publish] is true. Returns `(familyId, storyId)`.
Future<(String, String)> liveFamilyStory(
  Client owner, {
  bool publish = false,
}) async {
  final familyId = await owner.family.createRoot('Live family');
  final people = await owner.people.listFamily(familyId);
  final place = await owner.place.create(
    familyId,
    PlaceInputDto(
      label: 'Home',
      address: '1 Main St',
      lat: 51.5,
      lng: -0.1,
      isFavorite: false,
    ),
  );
  final story = await owner.story.createDraft(
    familyId,
    StoryWriteDto(
      title: 'Jam',
      body: 'We made jam.',
      dateStart: DateTime.utc(1980),
      datePrecision: DatePrecision.year,
      clearPlace: false,
      placeId: place.id,
      personIds: [for (final p in people) p.id],
    ),
    allowUndated: false,
  );
  if (publish) await owner.story.publish(story.id);
  return (familyId.toString(), story.id.toString());
}

/// Signs [member] into [familyId] through an invite created by [owner].
Future<void> joinLiveFamily(
  Client owner,
  Client member,
  String familyId,
) async {
  final invite = await owner.invite.create(UuidValue.fromString(familyId));
  await member.invite.accept(invite.token);
}

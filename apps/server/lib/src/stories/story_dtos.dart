import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// [stories] as [StoryDto]s, in the same order. The query count is fixed
/// (tags, people, photos, places, authors, note counts), whatever the number
/// of stories, so list endpoints never fan out per story.
Future<List<StoryDto>> storyDtos(Session session, List<Story> stories) async {
  if (stories.isEmpty) return [];
  final storyIds = {for (final story in stories) story.id!};

  final tags = await StoryPerson.db.find(
    session,
    where: (t) => t.storyId.inSet(storyIds),
  );
  final storiesByPerson = <UuidValue, List<UuidValue>>{};
  for (final tag in tags) {
    (storiesByPerson[tag.personId] ??= []).add(tag.storyId);
  }
  final people = storiesByPerson.isEmpty
      ? <Person>[]
      : await Person.db.find(
          session,
          where: (t) => t.id.inSet(storiesByPerson.keys.toSet()),
          orderByList: (t) => [t.name.asc(), t.id.asc()],
        );
  final peopleByStory = <UuidValue, List<StoryPersonDto>>{};
  for (final person in people) {
    for (final storyId in storiesByPerson[person.id]!) {
      (peopleByStory[storyId] ??= []).add(
        StoryPersonDto(
          personId: person.id!,
          name: person.name,
          userId: person.userId,
        ),
      );
    }
  }

  final photos = await Photo.db.find(
    session,
    where: (t) => t.storyId.inSet(storyIds),
    orderByList: (t) => [t.sortOrder.asc(), t.createdAt.asc(), t.id.asc()],
  );
  final photosByStory = <UuidValue, List<PhotoRefDto>>{};
  for (final photo in photos) {
    (photosByStory[photo.storyId] ??= []).add(
      PhotoRefDto(
        id: photo.id!,
        key: photo.editedKey ?? photo.originalKey,
        sortOrder: photo.sortOrder,
      ),
    );
  }

  final placeIds = {for (final story in stories) ?story.placeId};
  final places = placeIds.isEmpty
      ? <Place>[]
      : await Place.db.find(session, where: (t) => t.id.inSet(placeIds));
  final placeById = {for (final place in places) place.id!: place};

  final authorIds = {for (final story in stories) ?story.authorId};
  final authors = authorIds.isEmpty
      ? <AppUser>[]
      : await AppUser.db.find(
          session,
          where: (t) => t.authUserId.inSet(authorIds),
        );
  final authorById = {for (final user in authors) user.authUserId: user};

  final counts = await _noteCounts(session, storyIds);

  return [
    for (final story in stories)
      StoryDto(
        id: story.id!,
        familyId: story.familyId,
        authorId: story.authorId,
        title: story.title,
        body: story.body,
        dateStart: story.dateStart,
        dateEnd: story.dateEnd,
        datePrecision: story.datePrecision,
        createdAt: story.createdAt,
        placeId: story.placeId,
        placeLabel: placeById[story.placeId]?.label,
        placeAddress: placeById[story.placeId]?.address,
        status: story.status,
        publishedAt: story.publishedAt,
        people: peopleByStory[story.id] ?? [],
        photos: photosByStory[story.id] ?? [],
        authorName: authorById[story.authorId]?.displayName,
        authorAvatarKey: authorById[story.authorId]?.avatarKey,
        commentCount: counts[(story.id!, NoteKind.comment)] ?? 0,
        perspectiveCount: counts[(story.id!, NoteKind.perspective)] ?? 0,
      ),
  ];
}

/// Note counts per (story, kind), in one grouped query.
Future<Map<(UuidValue, NoteKind), int>> _noteCounts(
  Session session,
  Set<UuidValue> storyIds,
) async {
  final rows = await session.db.unsafeQuery(
    'SELECT "storyId"::text, "kind", count(*)::int FROM story_notes '
    'WHERE "storyId" = ANY(@ids::uuid[]) GROUP BY "storyId", "kind"',
    parameters: QueryParameters.named({
      'ids': [for (final id in storyIds) id.uuid],
    }),
  );
  return {
    for (final row in rows)
      (
        UuidValue.fromString(row[0] as String),
        NoteKind.fromJson(row[1] as String),
      ): row[2] as int,
  };
}

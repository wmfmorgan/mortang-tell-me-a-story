import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/data/server/media_batches.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';
import 'package:tell_me_a_story/core/domain/person_story_card.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';

/// The server's story. An undated draft keeps the default precision. The
/// server orders `photos` and resolves each to its edited key, so
/// [Story.photoPaths] keeps that order.
Story storyFromDto(server.StoryDto dto) => Story(
  id: dto.id.toString(),
  familyId: dto.familyId.toString(),
  authorId: dto.authorId?.toString() ?? '',
  title: dto.title,
  body: dto.body,
  timeframeStart: fromWireDate(dto.dateStart),
  timeframeEnd: fromWireDate(dto.dateEnd),
  datePrecision: switch (dto.datePrecision) {
    server.DatePrecision.year => StoryDatePrecision.year,
    server.DatePrecision.month => StoryDatePrecision.month,
    server.DatePrecision.day || null => StoryDatePrecision.day,
  },
  createdAt: dto.createdAt,
  placeId: dto.placeId?.toString(),
  status: switch (dto.status) {
    server.StoryStatus.draft => StoryStatus.draft,
    server.StoryStatus.published => StoryStatus.published,
  },
  publishedAt: dto.publishedAt,
  personIds: [for (final person in dto.people) person.personId.toString()],
  photoCount: dto.photos.length,
  placeLabel: _trimmed(dto.placeLabel),
  people: [
    for (final person in dto.people)
      if (_trimmed(person.name) case final name?)
        (id: person.personId.toString(), name: name),
  ],
  personNames: [for (final person in dto.people) ?_trimmed(person.name)],
  authorDisplayName: _trimmed(dto.authorName),
  authorAvatarPath: _trimmed(dto.authorAvatarKey),
  commentCount: dto.commentCount,
  perspectiveCount: dto.perspectiveCount,
  photoPaths: [for (final photo in dto.photos) photo.key],
  placeAddress: _trimmed(dto.placeAddress),
  personUserIds: {
    for (final person in dto.people)
      if (person.userId case final userId?)
        person.personId.toString(): userId.toString(),
  },
);

/// Trimmed [value]; null when it is null or blank.
String? _trimmed(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _profileWhen(Story story) {
  final start = story.timeframeStart;
  if (start == null) return '';
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  switch (story.datePrecision) {
    case StoryDatePrecision.year:
      return '${start.year}';
    case StoryDatePrecision.month:
      return '${months[start.month - 1]} ${start.year}';
    case StoryDatePrecision.day:
      return '${months[start.month - 1]} ${start.day}, ${start.year}';
  }
}

/// The story gateway on the server's `story` endpoint.
class ServerStoriesRepository implements StoriesRepository {
  ServerStoriesRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<Story> createDraft({
    String? id,
    required String familyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    bool allowUndated = false,
    List<String> personIds = const [],
  }) async {
    if (!allowUndated) {
      ensureValidDraftSave(timeframeStart: timeframeStart);
    }
    // The server makes a retried create of the same [id] one draft.
    final dto = await withServerErrors(
      () => _client.story.createDraft(
        _uuid(familyId),
        storyWriteDto(
          timeframeStart: timeframeStart,
          timeframeEnd: timeframeEnd,
          datePrecision: datePrecision,
          title: title,
          body: body,
          placeId: placeId,
          personIds: personIds,
        ),
        id: id == null ? null : _uuid(id),
        allowUndated: allowUndated,
      ),
    );
    return storyFromDto(dto);
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    final dto = await withServerErrors(
      () => _client.story.updateDraft(
        _uuid(storyId),
        storyWriteDto(
          timeframeStart: timeframeStart,
          timeframeEnd: timeframeEnd,
          datePrecision: datePrecision,
          title: title,
          body: body,
          placeId: placeId,
          personIds: personIds,
        ),
      ),
    );
    return storyFromDto(dto);
  }

  @override
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) {
    return withServerErrors(
      () => _client.story.autosaveDraft(
        _uuid(storyId),
        storyWriteDto(
          timeframeStart: timeframeStart,
          timeframeEnd: timeframeEnd,
          datePrecision: datePrecision,
          title: title,
          body: body,
          placeId: placeId,
          personIds: personIds,
        ),
      ),
    );
  }

  /// The server checks publish readiness and refuses with `validation`.
  @override
  Future<Story> publish(String storyId) async => storyFromDto(
    await withServerErrors(() => _client.story.publish(_uuid(storyId))),
  );

  @override
  Future<Story> getStory(String storyId) async => storyFromDto(
    await withServerErrors(() => _client.story.get(_uuid(storyId))),
  );

  @override
  Future<Story?> getPublished(String storyId) async {
    final dto = await withServerErrors(
      () => _client.story.getPublished(_uuid(storyId)),
    );
    return dto == null ? null : storyFromDto(dto);
  }

  /// Published stories tagged with [personId] in live families of its tree,
  /// oldest first, each with its first photo.
  @override
  Future<List<PersonStoryCard>> storiesForPerson(String personId) async {
    final stories = await _stories(
      () => _client.story.listForPerson(_uuid(personId)),
    );
    final thumbs = await downloadFirstThumbs(stories, null, client: _client);
    return [
      for (final story in stories)
        PersonStoryCard(
          id: story.id,
          title: storedStoryTitle(story.title) ?? 'Untitled',
          whenLabel: _profileWhen(story),
          place: story.placeLabel,
          photoCount: story.photoCount,
          thumbBytes: thumbs[story.id],
        ),
    ];
  }

  /// The caller's drafts, in timeline order with undated drafts last.
  @override
  Future<List<Story>> listMyDrafts(String familyId) =>
      _stories(() => _client.story.listMyDrafts(_uuid(familyId)));

  @override
  Future<List<Story>> listPublished(String familyId) =>
      _stories(() => _client.story.listPublished(_uuid(familyId)));

  @override
  Future<List<Story>> listPublishedInTree(String familyId) =>
      _stories(() => _client.story.listPublishedInTree(_uuid(familyId)));

  @override
  Future<Story?> getPublishedOrigin(String storyId) => getPublished(storyId);

  /// The server's clock sets the window; [now] only matters to fakes.
  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) => _stories(
    () => _client.story.listLatestPublished(
      _uuid(familyId),
      withinDays: withinDays,
      limit: limit,
    ),
  );

  @override
  Future<void> discard(String storyId) =>
      withServerErrors(() => _client.story.discard(_uuid(storyId)));

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) => withServerErrors(
    () => _client.story.linkPerson(_uuid(storyId), _uuid(personId)),
  );

  Future<List<Story>> _stories(
    Future<List<server.StoryDto>> Function() call,
  ) async => [
    for (final dto in await withServerErrors(call)) storyFromDto(dto),
  ];
}

server.UuidValue _uuid(String id) => server.UuidValue.fromString(id);

/// The server's write payload for the [StoriesRepository] fields. A null field
/// keeps the stored value, an empty [placeId] clears the place, and a
/// [personIds] list, even an empty one, replaces the tags.
server.StoryWriteDto storyWriteDto({
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
  String? datePrecision,
  String? title,
  String? body,
  String? placeId,
  List<String>? personIds,
}) => server.StoryWriteDto(
  dateStart: toWireDate(timeframeStart),
  dateEnd: toWireDate(timeframeEnd),
  datePrecision: precisionFromName(datePrecision),
  title: title,
  body: body,
  placeId: placeId == null || placeId.isEmpty ? null : _uuid(placeId),
  clearPlace: placeId != null && placeId.isEmpty,
  personIds: personIds == null ? null : [for (final id in personIds) _uuid(id)],
);

/// First photo of each story, by story id. A missing or empty blob is
/// omitted. With [photos] (tests) each key is downloaded once; without it the
/// keys go to `media.getMany` on [client] (default [serverClient]) in
/// batches ([getMediaBatched]), so a failed batch blanks only its thumbs.
Future<Map<String, Uint8List>> downloadFirstThumbs(
  List<Story> stories,
  PhotosRepository? photos, {
  server.Client? client,
}) async {
  final keys = {
    for (final story in stories)
      if (story.photoPaths.isNotEmpty) story.photoPaths.first,
  };
  if (keys.isEmpty) return const {};
  final bytes = photos == null
      ? await getMediaBatched(client ?? serverClient, keys)
      : await _downloadEach(photos, keys);
  final out = <String, Uint8List>{};
  for (final story in stories) {
    if (story.photoPaths.isEmpty) continue;
    final data = bytes[story.photoPaths.first];
    if (data != null && data.isNotEmpty) out[story.id] = data;
  }
  return out;
}

Future<Map<String, Uint8List>> _downloadEach(
  PhotosRepository photos,
  Set<String> keys,
) async {
  final out = <String, Uint8List>{};
  for (final key in keys) {
    try {
      out[key] = await photos.downloadBytes(key);
    } catch (_) {
      // A missing thumb stays a parchment blank.
    }
  }
  return out;
}

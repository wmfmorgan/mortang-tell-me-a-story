import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/server/media_batches.dart';
import 'package:tell_me_a_story/data/server/server_errors.dart';
import 'package:tell_me_a_story/data/server/wire.dart';

enum StoryStatus { draft, published }

/// Coarse to fine, like the server's `DatePrecision`; timeline order sorts
/// on it. `decade` was dropped (D9).
enum StoryDatePrecision { year, month, day }

StoryDatePrecision storyDatePrecisionFrom(String? raw) {
  for (final value in StoryDatePrecision.values) {
    if (value.name == raw) return value;
  }
  return StoryDatePrecision.day;
}

class Story {
  const Story({
    required this.id,
    required this.familyId,
    required this.authorId,
    this.title,
    this.body,
    this.timeframeStart,
    this.timeframeEnd,
    this.datePrecision = StoryDatePrecision.day,
    this.createdAt,
    this.placeId,
    required this.status,
    this.publishedAt,
    this.personIds = const [],
    this.photoCount = 0,
    this.placeLabel,
    this.people = const [],
    this.personNames = const [],
    this.authorDisplayName,
    this.authorAvatarPath,
    this.commentCount = 0,
    this.perspectiveCount = 0,
    this.photoPaths = const [],
    this.placeAddress,
    this.personUserIds = const {},
  });
  final String id;
  final String familyId;
  final String authorId;
  final String? title;
  final String? body;
  final DateTime? timeframeStart; // date only; null until the author sets one

  /// Start date of a published story. A published row always has one.
  DateTime get publishedStart {
    final start = timeframeStart;
    if (start == null) {
      throw StateError('published story $id is missing a start date');
    }
    return start;
  }

  final DateTime? timeframeEnd;
  final StoryDatePrecision datePrecision;
  final DateTime? createdAt;
  final String? placeId;
  final StoryStatus status;
  final DateTime? publishedAt;
  final List<String> personIds;
  final int photoCount;
  final String? placeLabel;

  /// Id and name for each tagged person. [personNames] stays for name search.
  final List<({String id, String name})> people;
  final List<String> personNames;
  final String? authorDisplayName;
  final String? authorAvatarPath;
  final int commentCount;
  final int perspectiveCount;
  final List<String> photoPaths;

  /// `places.address`, trimmed. Null when the embed is missing or blank.
  final String? placeAddress;

  /// `story_people.person_id` to `people.user_id`, only when both are non-empty.
  final Map<String, String> personUserIds;

  /// The server's story. An undated draft keeps the default precision. The
  /// server orders `photos` and resolves each to its edited key, so
  /// [photoPaths] keeps that order.
  factory Story.fromDto(server.StoryDto dto) => Story(
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
}

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

/// One published story on a person profile.
class PersonStoryCard {
  const PersonStoryCard({
    required this.id,
    required this.title,
    required this.whenLabel,
    this.place,
    this.photoCount = 0,
    this.thumbBytes,
  });

  final String id;
  final String title;
  final String whenLabel;
  final String? place;
  final int photoCount;
  final Uint8List? thumbBytes;
}

class PublishReadiness {
  const PublishReadiness({
    required this.hasTitle,
    required this.hasBody,
    required this.hasTimeframe,
    required this.hasPerson,
    required this.hasPlace,
  });
  final bool hasTitle;
  final bool hasBody;
  final bool hasTimeframe;
  final bool hasPerson;
  final bool hasPlace;
  bool get canPublish =>
      hasTitle && hasBody && hasTimeframe && hasPerson && hasPlace;
}

PublishReadiness publishReadiness({
  required String? title,
  required String? body,
  required DateTime? timeframeStart,
  required Iterable<String> personIds,
  required String? placeId,
}) {
  return PublishReadiness(
    hasTitle: (title ?? '').trim().isNotEmpty,
    hasBody: (body ?? '').trim().isNotEmpty,
    hasTimeframe: timeframeStart != null,
    hasPerson: personIds.isNotEmpty,
    hasPlace: placeId != null && placeId.isNotEmpty,
  );
}

/// Whitespace-only titles are stored as null so a saved title can be cleared.
String? storedStoryTitle(String? title) {
  if (title == null) return null;
  final trimmed = title.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void ensureValidDraftSave({required DateTime? timeframeStart}) {
  if (timeframeStart == null) {
    throw ArgumentError.value(
      timeframeStart,
      'timeframeStart',
      'must be set before save draft',
    );
  }
}

abstract class StoriesGateway {
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
  });

  /// A null [personIds] leaves the story's story_people rows as they are. A list, even an empty one, replaces them.
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  });

  /// Autosave and save-on-leave only. False when the row is no longer a draft.
  /// A null [personIds] leaves the story's story_people rows as they are. A list, even an empty one, replaces them.
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  });
  Future<Story> publish(String storyId);
  Future<Story> getStory(String storyId);
  Future<Story?> getPublished(String storyId);
  Future<List<Story>> listMyDrafts(String familyId);
  Future<List<Story>> listPublished(String familyId);

  /// Published stories of every live family in [familyId]'s tree, in
  /// timeline order. Tree readers of a live family only.
  Future<List<Story>> listPublishedInTree(String familyId);

  /// Published story by id using the published-list select. Null when not found or not readable.
  Future<Story?> getPublishedOrigin(String storyId);

  /// Published stories added in the past [withinDays], newest first, at most [limit].
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  });

  /// Deletes the caller's own story with its photos, notes and tags.
  Future<void> discard(String storyId);

  /// Tags [personId] on the story. Does not replace the story's other
  /// people; a repeat is a no-op.
  Future<void> linkPerson({required String storyId, required String personId});
}

/// The story gateway on the server's `story` endpoint.
class StoriesApi implements StoriesGateway {
  StoriesApi({server.Client? client}) : _injected = client;

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
    return Story.fromDto(dto);
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
    return Story.fromDto(dto);
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
  Future<Story> publish(String storyId) async => Story.fromDto(
    await withServerErrors(() => _client.story.publish(_uuid(storyId))),
  );

  @override
  Future<Story> getStory(String storyId) async => Story.fromDto(
    await withServerErrors(() => _client.story.get(_uuid(storyId))),
  );

  @override
  Future<Story?> getPublished(String storyId) async {
    final dto = await withServerErrors(
      () => _client.story.getPublished(_uuid(storyId)),
    );
    return dto == null ? null : Story.fromDto(dto);
  }

  /// Published stories tagged with [personId] in live families of its tree,
  /// oldest first, each with its first photo.
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
    for (final dto in await withServerErrors(call)) Story.fromDto(dto),
  ];
}

server.UuidValue _uuid(String id) => server.UuidValue.fromString(id);

/// The server's write payload for the [StoriesGateway] fields. A null field
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

/// Start of the Latest window. A story at this instant is included.
DateTime latestPublishedCutoff(DateTime now, {int withinDays = 7}) {
  return now.toUtc().subtract(Duration(days: withinDays));
}

/// Published rows with `published_at` inside the window, newest first.
List<Story> latestShelf(
  Iterable<Story> stories, {
  required DateTime now,
  int withinDays = 7,
  int limit = 3,
}) {
  final cutoff = latestPublishedCutoff(now, withinDays: withinDays);
  final rows = [
    for (final story in stories)
      if (story.status == StoryStatus.published &&
          story.publishedAt != null &&
          !story.publishedAt!.toUtc().isBefore(cutoff))
        story,
  ];
  rows.sort((a, b) {
    final byTime = b.publishedAt!.compareTo(a.publishedAt!);
    if (byTime != 0) return byTime;
    return b.id.compareTo(a.id);
  });
  if (rows.length <= limit) return rows;
  return rows.sublist(0, limit);
}

/// Oldest first: start, precision, created_at, id. Newest-first is the reverse.
int compareStories(Story a, Story b) {
  final aStart = a.timeframeStart;
  final bStart = b.timeframeStart;
  if (aStart == null || bStart == null) {
    if (aStart == null && bStart != null) return 1;
    if (aStart != null && bStart == null) return -1;
  } else {
    final start = DateTime(
      aStart.year,
      aStart.month,
      aStart.day,
    ).compareTo(DateTime(bStart.year, bStart.month, bStart.day));
    if (start != 0) return start;
  }
  final precision = a.datePrecision.index.compareTo(b.datePrecision.index);
  if (precision != 0) return precision;
  final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final created = aCreated.compareTo(bCreated);
  if (created != 0) return created;
  return a.id.compareTo(b.id);
}

/// First photo of each story, by story id. A missing or empty blob is
/// omitted. With [photos] (tests) each key is downloaded once; without it the
/// keys go to `media.getMany` on [client] (default [serverClient]) in
/// batches ([getMediaBatched]), so a failed batch blanks only its thumbs.
Future<Map<String, Uint8List>> downloadFirstThumbs(
  List<Story> stories,
  PhotosGateway? photos, {
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
  PhotosGateway photos,
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

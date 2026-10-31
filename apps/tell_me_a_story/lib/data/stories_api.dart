import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'photos_api.dart';

enum StoryStatus { draft, published }

/// Declaration order matches Postgres `story_date_precision`.
enum StoryDatePrecision { decade, year, month, day }

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

  factory Story.fromJson(Map<String, dynamic> json) {
    final people = json['story_people'];
    final photos = json['photos'];
    return Story(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      authorId: json['author_id'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      timeframeStart: json['timeframe_start'] == null
          ? null
          : _parseDate(json['timeframe_start'] as String),
      timeframeEnd: json['timeframe_end'] != null
          ? _parseDate(json['timeframe_end'] as String)
          : null,
      datePrecision: storyDatePrecisionFrom(json['date_precision'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      placeId: json['place_id'] as String?,
      status: _storyStatusFrom(json['status'] as String),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      personIds: people is List
          ? people.map((row) => (row as Map)['person_id'] as String).toList()
          : const [],
      photoCount: photos is List ? photos.length : 0,
      placeLabel: _embedLabel(json['places']),
      people: _storyPeople(people),
      personNames: _personNames(people),
      authorDisplayName: _authorName(json['profiles']),
      authorAvatarPath: _authorAvatarPath(json['profiles']),
      commentCount: _rowCount(json['comments']),
      perspectiveCount: _rowCount(json['perspectives']),
      photoPaths: _photoPaths(photos),
      placeAddress: _embedAddress(json['places']),
      personUserIds: _personUserIds(json['story_people']),
    );
  }
}

String? _embedLabel(Object? places) {
  if (places is Map) {
    final label = places['label'];
    if (label is String && label.trim().isNotEmpty) return label.trim();
  }
  return null;
}

String? _embedAddress(Object? places) {
  if (places is Map) {
    final address = places['address'];
    if (address is String && address.trim().isNotEmpty) return address.trim();
  }
  return null;
}

Map<String, String> _personUserIds(Object? people) {
  if (people is! List) return const {};
  final out = <String, String>{};
  for (final row in people) {
    if (row is! Map) continue;
    final personId = row['person_id'];
    final nested = row['people'];
    if (nested is! Map) continue;
    final userId = nested['user_id'];
    if (personId is! String || personId.isEmpty) continue;
    if (userId is! String || userId.trim().isEmpty) continue;
    out[personId] = userId.trim();
  }
  return out;
}

List<({String id, String name})> _storyPeople(Object? people) {
  if (people is! List) return const [];
  final out = <({String id, String name})>[];
  for (final row in people) {
    if (row is! Map) continue;
    final nested = row['people'];
    String? name;
    var id = row['person_id'] as String?;
    if (nested is Map) {
      final rawName = nested['name'];
      if (rawName is String && rawName.trim().isNotEmpty) name = rawName.trim();
      id ??= nested['id'] as String?;
    }
    if (id != null && id.isNotEmpty && name != null) {
      out.add((id: id, name: name));
    }
  }
  return out;
}

List<String> _personNames(Object? people) {
  if (people is! List) return const [];
  final names = <String>[];
  for (final row in people) {
    if (row is! Map) continue;
    final nested = row['people'];
    if (nested is Map) {
      final name = nested['name'];
      if (name is String && name.trim().isNotEmpty) names.add(name.trim());
    }
  }
  return names;
}

Map<String, dynamic>? _authorProfile(Object? profiles) {
  if (profiles is Map) {
    return profiles.map((key, value) => MapEntry(key.toString(), value));
  }
  if (profiles is List && profiles.isNotEmpty && profiles.first is Map) {
    final first = profiles.first as Map;
    return first.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? _authorName(Object? profiles) {
  final map = _authorProfile(profiles);
  if (map == null) return null;
  final name = map['display_name'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  return null;
}

String? _authorAvatarPath(Object? profiles) {
  final map = _authorProfile(profiles);
  if (map == null) return null;
  final path = map['avatar_path'];
  if (path is String && path.trim().isNotEmpty) return path.trim();
  return null;
}

int _rowCount(Object? rows) => rows is List ? rows.length : 0;

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
    case StoryDatePrecision.decade:
      final year = start.year - (start.year % 10);
      return '${year}s';
    case StoryDatePrecision.year:
      return '${start.year}';
    case StoryDatePrecision.month:
      return '${months[start.month - 1]} ${start.year}';
    case StoryDatePrecision.day:
      return '${months[start.month - 1]} ${start.day}, ${start.year}';
  }
}

List<String> _photoPaths(Object? photos) {
  if (photos is! List) return const [];
  final rows = photos.whereType<Map>().toList();
  rows.sort(
    (a, b) => ((a['sort_order'] as int?) ?? 0).compareTo(
      (b['sort_order'] as int?) ?? 0,
    ),
  );
  return [
    for (final row in rows)
      if (row['storage_path'] is String) row['storage_path'] as String,
  ];
}

/// One published story on a person profile.
class PersonStoryCard {
  const PersonStoryCard({
    required this.id,
    required this.title,
    required this.whenLabel,
    this.place,
    this.photoCount = 0,
    this.thumbUrl,
  });

  final String id;
  final String title;
  final String whenLabel;
  final String? place;
  final int photoCount;
  final String? thumbUrl;
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

/// A retried insert of the same client id. The caller updates that row.
bool isDuplicateStoryKey(Object error) {
  if (error is! PostgrestException) return false;
  if (error.code == '23505') return true;
  final message = error.message.toLowerCase();
  return message.contains('duplicate key');
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

  /// Published story by id using the published-list select. Null when not found or not readable.
  Future<Story?> getPublishedOrigin(String storyId);

  /// Published stories added in the past [withinDays], newest first, at most [limit].
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  });

  Future<void> discard(String storyId);

  /// One `story_people` insert. Does not replace the story's other people.
  Future<void> linkPerson({required String storyId, required String personId});
}

/// PostgREST CRUD gateway for family-scoped `stories` rows.
class StoriesApi implements StoriesGateway {
  StoriesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _storySelect =
      'id, family_id, author_id, title, body, timeframe_start, timeframe_end, date_precision, created_at, place_id, status, published_at, story_people(person_id), photos(id), profiles!author_id(display_name, avatar_path)';

  static const _publishedSelect =
      'id, family_id, author_id, title, body, timeframe_start, timeframe_end, date_precision, created_at, place_id, status, published_at, places(label, address), story_people(person_id, people(name, user_id)), profiles!author_id(display_name, avatar_path), photos(id, storage_path, sort_order), comments(id), perspectives(id)';

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
    final uid = _client.auth.currentUser!.id;
    final payload = <String, dynamic>{
      'family_id': familyId,
      'author_id': uid,
      'title': storedStoryTitle(title),
      'body': body?.trim(),
      'timeframe_start': timeframeStart == null ? null : _date(timeframeStart),
      'timeframe_end': timeframeEnd == null ? null : _date(timeframeEnd),
      if (datePrecision != null) 'date_precision': datePrecision,
      'place_id': placeId,
      'status': 'draft',
    };
    if (id != null) payload['id'] = id;
    final row = await _client
        .from('stories')
        .insert(payload)
        .select(_storySelect)
        .single();
    final story = Story.fromJson(row);
    await _replacePeople(story.id, personIds);
    return getStory(story.id);
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
    // The bool is ignored on purpose. It only reports "no longer a draft" for autosave (draftsOnly); getStory below returns the row as stored.
    await _applyStoryWrite(
      storyId: storyId,
      draftsOnly: false,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: datePrecision,
      title: title,
      body: body,
      placeId: placeId,
      personIds: personIds,
    );
    return getStory(storyId);
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
    return _applyStoryWrite(
      storyId: storyId,
      draftsOnly: true,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: datePrecision,
      title: title,
      body: body,
      placeId: placeId,
      personIds: personIds,
    );
  }

  /// Story update plus `story_people` replace. [draftsOnly] is the only fork.
  Future<bool> _applyStoryWrite({
    required String storyId,
    required bool draftsOnly,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    if (timeframeStart != null) {
      ensureValidDraftSave(timeframeStart: timeframeStart);
    }
    final patch = <String, dynamic>{};
    if (timeframeStart != null) {
      patch['timeframe_start'] = _date(timeframeStart);
    }
    if (timeframeEnd != null) {
      patch['timeframe_end'] = _date(timeframeEnd);
    }
    if (datePrecision != null) {
      patch['date_precision'] = datePrecision;
    }
    // Null leaves the column alone. A blank string clears a saved title.
    if (title != null) {
      patch['title'] = storedStoryTitle(title);
    }
    if (body != null) {
      patch['body'] = body.trim();
    }
    if (placeId != null) {
      patch['place_id'] = placeId.isEmpty ? null : placeId;
    }
    if (patch.isNotEmpty) {
      var update = _client.from('stories').update(patch).eq('id', storyId);
      if (draftsOnly) {
        update = update.eq('status', 'draft');
      }
      final rows = await update.select('id');
      if (rows.isEmpty) return false;
    } else if (draftsOnly) {
      final rows = await _client
          .from('stories')
          .select('id')
          .eq('id', storyId)
          .eq('status', 'draft');
      if (rows.isEmpty) return false;
    }
    if (personIds != null) {
      await _replacePeople(storyId, personIds);
    }
    return true;
  }

  @override
  Future<Story> publish(String storyId) async {
    final story = await getStory(storyId);
    if (!publishReadiness(
      title: story.title,
      body: story.body,
      timeframeStart: story.timeframeStart,
      personIds: story.personIds,
      placeId: story.placeId,
    ).canPublish) {
      throw ArgumentError('VALIDATION');
    }
    await _client
        .from('stories')
        .update({
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', storyId);
    return getStory(storyId);
  }

  @override
  Future<Story> getStory(String storyId) async {
    final row = await _client
        .from('stories')
        .select(_storySelect)
        .eq('id', storyId)
        .single();
    return Story.fromJson(row);
  }

  @override
  Future<Story?> getPublished(String storyId) {
    return _getPublishedWith(storyId, _storySelect);
  }

  /// Published stories tagged with [personId], oldest first.
  Future<List<PersonStoryCard>> storiesForPerson(String personId) async {
    final rows = await _client
        .from('stories')
        .select(
          'id, family_id, author_id, title, body, timeframe_start, timeframe_end, '
          'date_precision, created_at, place_id, status, published_at, '
          'places(label), story_people!inner(person_id, people(name)), '
          'profiles!author_id(display_name, avatar_path), '
          'photos(id, storage_path, sort_order)',
        )
        .eq('status', 'published')
        .eq('story_people.person_id', personId)
        .order('timeframe_start');
    final cards = <PersonStoryCard>[];
    for (final row in rows) {
      final story = Story.fromJson(row);
      final title = story.title?.trim() ?? '';
      String? thumb;
      final path = story.photoPaths.isEmpty ? null : story.photoPaths.first;
      if (path != null && path.isNotEmpty) {
        try {
          thumb = await _client.storage
              .from(storyPhotosBucket)
              .createSignedUrl(path, 3600);
        } catch (_) {
          thumb = null;
        }
      }
      cards.add(
        PersonStoryCard(
          id: story.id,
          title: title.isEmpty ? 'Untitled' : title,
          whenLabel: _profileWhen(story),
          place: story.placeLabel,
          photoCount: story.photoCount,
          thumbUrl: thumb,
        ),
      );
    }
    return cards;
  }

  @override
  Future<List<Story>> listMyDrafts(String familyId) async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('stories')
        .select(_storySelect)
        .eq('family_id', familyId)
        .eq('status', 'draft')
        .eq('author_id', uid)
        .order('timeframe_start', nullsFirst: false)
        .order('date_precision')
        .order('created_at')
        .order('id');
    final stories = rows.map(Story.fromJson).toList();
    stories.sort(compareStories);
    return stories;
  }

  @override
  Future<List<Story>> listPublished(String familyId) async {
    final rows = await _client
        .from('stories')
        .select(_publishedSelect)
        .eq('family_id', familyId)
        .eq('status', 'published')
        .order('timeframe_start')
        .order('date_precision')
        .order('created_at')
        .order('id');
    return rows.map(Story.fromJson).toList();
  }

  @override
  Future<Story?> getPublishedOrigin(String storyId) {
    return _getPublishedWith(storyId, _publishedSelect);
  }

  Future<Story?> _getPublishedWith(String storyId, String select) async {
    final row = await _client
        .from('stories')
        .select(select)
        .eq('id', storyId)
        .eq('status', 'published')
        .maybeSingle();
    if (row == null) return null;
    return Story.fromJson(row);
  }

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async {
    final cutoff = latestPublishedCutoff(
      now ?? DateTime.now(),
      withinDays: withinDays,
    );
    final rows = await _client
        .from('stories')
        .select(
          'id, family_id, author_id, title, timeframe_start, timeframe_end, date_precision, status, published_at, photos(id, storage_path, sort_order)',
        )
        .eq('family_id', familyId)
        .eq('status', 'published')
        .gte('published_at', cutoff.toUtc().toIso8601String())
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return latestShelf(
      rows.map(Story.fromJson),
      now: now ?? DateTime.now(),
      withinDays: withinDays,
      limit: limit,
    );
  }

  @override
  Future<void> discard(String storyId) async {
    await _client.from('stories').delete().eq('id', storyId);
  }

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {
    await _client.from('story_people').insert({
      'story_id': storyId,
      'person_id': personId,
    });
  }

  Future<void> _replacePeople(String storyId, List<String> personIds) async {
    await _client.from('story_people').delete().eq('story_id', storyId);
    if (personIds.isEmpty) return;
    await _client.from('story_people').insert([
      for (final personId in personIds)
        {'story_id': storyId, 'person_id': personId},
    ]);
  }
}

/// Writes calendar dates as `YYYY-MM-DD` for Postgres `date` columns.
String _date(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

int decadeStartYear(DateTime start) => (start.year ~/ 10) * 10;

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

DateTime _parseDate(String raw) {
  final parts = raw.split('T').first.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

StoryStatus _storyStatusFrom(String raw) {
  return switch (raw) {
    'published' => StoryStatus.published,
    'draft' => StoryStatus.draft,
    _ => throw ArgumentError.value(raw, 'status'),
  };
}

/// First photo of each story. A missing or empty file is omitted.
/// A null gateway downloads nothing unless a story has a photo path, in
/// which case it uses [PhotosApi].
Future<Map<String, Uint8List>> downloadFirstThumbs(
  List<Story> stories,
  PhotosGateway? photos,
) async {
  final gateway = switch (photos) {
    final given? => given,
    null when stories.any((story) => story.photoPaths.isNotEmpty) =>
      PhotosApi(),
    null => null,
  };
  if (gateway == null) return const {};
  final out = <String, Uint8List>{};
  for (final story in stories) {
    if (story.photoPaths.isEmpty) continue;
    try {
      final bytes = await gateway.downloadBytes(story.photoPaths.first);
      if (bytes.isNotEmpty) out[story.id] = bytes;
    } catch (_) {
      // A missing thumb stays a parchment blank.
    }
  }
  return out;
}

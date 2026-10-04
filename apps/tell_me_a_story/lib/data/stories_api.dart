import 'package:supabase_flutter/supabase_flutter.dart';

enum StoryStatus { draft, published }

class Story {
  const Story({
    required this.id,
    required this.familyId,
    required this.authorId,
    this.title,
    this.body,
    required this.timeframeStart,
    this.timeframeEnd,
    this.placeId,
    required this.status,
    this.publishedAt,
    this.personIds = const [],
    this.photoCount = 0,
    this.placeLabel,
    this.personNames = const [],
    this.authorDisplayName,
    this.commentCount = 0,
    this.perspectiveCount = 0,
    this.photoPaths = const [],
  });
  final String id;
  final String familyId;
  final String authorId;
  final String? title;
  final String? body;
  final DateTime timeframeStart; // date only
  final DateTime? timeframeEnd;
  final String? placeId;
  final StoryStatus status;
  final DateTime? publishedAt;
  final List<String> personIds;
  final int photoCount;
  final String? placeLabel;
  final List<String> personNames;
  final String? authorDisplayName;
  final int commentCount;
  final int perspectiveCount;
  final List<String> photoPaths;

  factory Story.fromJson(Map<String, dynamic> json) {
    final people = json['story_people'];
    final photos = json['photos'];
    return Story(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      authorId: json['author_id'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      timeframeStart: _parseDate(json['timeframe_start'] as String),
      timeframeEnd: json['timeframe_end'] != null
          ? _parseDate(json['timeframe_end'] as String)
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
      personNames: _personNames(people),
      authorDisplayName: _authorName(json['profiles']),
      commentCount: _rowCount(json['comments']),
      perspectiveCount: _rowCount(json['perspectives']),
      photoPaths: _photoPaths(photos),
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

String? _authorName(Object? profiles) {
  final map = profiles is Map
      ? profiles
      : (profiles is List && profiles.isNotEmpty && profiles.first is Map
            ? profiles.first as Map
            : null);
  if (map == null) return null;
  final name = map['display_name'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  return null;
}

int _rowCount(Object? rows) => rows is List ? rows.length : 0;

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
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? title,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  });
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
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
  Future<void> discard(String storyId);
}

/// PostgREST CRUD gateway for family-scoped `stories` rows.
class StoriesApi implements StoriesGateway {
  StoriesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _storySelect =
      'id, family_id, author_id, title, body, timeframe_start, timeframe_end, place_id, status, published_at, story_people(person_id), photos(id)';

  static const _publishedSelect =
      'id, family_id, author_id, title, body, timeframe_start, timeframe_end, place_id, status, published_at, places(label), story_people(person_id, people(name)), profiles!author_id(display_name), photos(id, storage_path, sort_order), comments(id), perspectives(id)';

  @override
  Future<Story> createDraft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? title,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  }) async {
    ensureValidDraftSave(timeframeStart: timeframeStart);
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('stories')
        .insert({
          'family_id': familyId,
          'author_id': uid,
          'title': storedStoryTitle(title),
          'body': body?.trim(),
          'timeframe_start': _date(timeframeStart),
          'timeframe_end': timeframeEnd == null ? null : _date(timeframeEnd),
          'place_id': placeId,
          'status': 'draft',
        })
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
      await _client.from('stories').update(patch).eq('id', storyId);
    }
    if (personIds != null) {
      await _replacePeople(storyId, personIds);
    }
    return getStory(storyId);
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
  Future<Story?> getPublished(String storyId) async {
    final row = await _client
        .from('stories')
        .select(_storySelect)
        .eq('id', storyId)
        .eq('status', 'published')
        .maybeSingle();
    if (row == null) return null;
    return Story.fromJson(row);
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
        .order('timeframe_start');
    return rows.map(Story.fromJson).toList();
  }

  @override
  Future<List<Story>> listPublished(String familyId) async {
    final rows = await _client
        .from('stories')
        .select(_publishedSelect)
        .eq('family_id', familyId)
        .eq('status', 'published')
        .order('timeframe_start');
    return rows.map(Story.fromJson).toList();
  }

  @override
  Future<void> discard(String storyId) async {
    await _client.from('stories').delete().eq('id', storyId);
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

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
    );
  }
}

class PublishReadiness {
  const PublishReadiness({
    required this.hasBody,
    required this.hasTimeframe,
    required this.hasPerson,
    required this.hasPlace,
  });
  final bool hasBody;
  final bool hasTimeframe;
  final bool hasPerson;
  final bool hasPlace;
  bool get canPublish => hasBody && hasTimeframe && hasPerson && hasPlace;
}

PublishReadiness publishReadiness({
  required String? body,
  required DateTime? timeframeStart,
  required Iterable<String> personIds,
  required String? placeId,
}) {
  return PublishReadiness(
    hasBody: (body ?? '').trim().isNotEmpty,
    hasTimeframe: timeframeStart != null,
    hasPerson: personIds.isNotEmpty,
    hasPlace: placeId != null && placeId.isNotEmpty,
  );
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
    String? body,
    String? placeId,
    List<String> personIds = const [],
  });
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
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

  @override
  Future<Story> createDraft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
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
        .select(_storySelect)
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

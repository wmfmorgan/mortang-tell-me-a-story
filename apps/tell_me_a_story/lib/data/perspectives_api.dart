import 'package:supabase_flutter/supabase_flutter.dart';

String displayNameOrMember(String? name) {
  final t = name?.trim() ?? '';
  return t.isEmpty ? 'Member' : t;
}

/// Rejects empty / whitespace-only body before network.
void ensureValidPerspectiveBody(String body) {
  if (body.trim().isEmpty) {
    throw ArgumentError.value(body, 'body', 'must not be empty');
  }
}

class Perspective {
  const Perspective({
    required this.id,
    required this.storyId,
    required this.familyId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorDisplayName,
  });
  final String id, storyId, familyId, authorId, body;
  final DateTime createdAt;
  final String? authorDisplayName;
  String get authorLabel => displayNameOrMember(authorDisplayName);

  factory Perspective.fromJson(Map<String, dynamic> json) {
    return Perspective(
      id: json['id'] as String,
      storyId: json['story_id'] as String,
      familyId: json['family_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorDisplayName: _authorDisplayName(json),
    );
  }
}

abstract class PerspectivesGateway {
  Future<List<Perspective>> listForStory(String storyId);
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  });
  Future<void> update({required String id, required String body});
  Future<void> delete(String id);
}

/// PostgREST CRUD gateway for family-scoped `perspectives` rows.
class PerspectivesApi implements PerspectivesGateway {
  PerspectivesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _select = '*, author:profiles!author_id(display_name)';

  @override
  Future<List<Perspective>> listForStory(String storyId) async {
    final rows = await _client
        .from('perspectives')
        .select(_select)
        .eq('story_id', storyId)
        .order('created_at');
    return rows.map(Perspective.fromJson).toList();
  }

  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    ensureValidPerspectiveBody(body);
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('perspectives')
        .insert({
          'story_id': storyId,
          'family_id': familyId,
          'author_id': uid,
          'body': body.trim(),
        })
        .select(_select)
        .single();
    return Perspective.fromJson(row);
  }

  @override
  Future<void> update({required String id, required String body}) async {
    ensureValidPerspectiveBody(body);
    await _client
        .from('perspectives')
        .update({'body': body.trim()})
        .eq('id', id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('perspectives').delete().eq('id', id);
  }
}

String? _authorDisplayName(Map<String, dynamic> json) {
  final author = json['author'];
  if (author is Map) {
    return author['display_name'] as String?;
  }
  return null;
}

import 'package:supabase_flutter/supabase_flutter.dart';

String displayNameOrMember(String? name) {
  final t = name?.trim() ?? '';
  return t.isEmpty ? 'Member' : t;
}

/// Rejects empty / whitespace-only body before network.
void ensureValidCommentBody(String body) {
  if (body.trim().isEmpty) {
    throw ArgumentError.value(body, 'body', 'must not be empty');
  }
}

class Comment {
  const Comment({
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

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
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

abstract class CommentsGateway {
  Future<List<Comment>> listForStory(String storyId);
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  });
  Future<void> update({required String id, required String body});
  Future<void> delete(String id);
}

/// PostgREST CRUD gateway for family-scoped `comments` rows.
class CommentsApi implements CommentsGateway {
  CommentsApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _select = '*, author:profiles!author_id(display_name)';

  @override
  Future<List<Comment>> listForStory(String storyId) async {
    final rows = await _client
        .from('comments')
        .select(_select)
        .eq('story_id', storyId)
        .order('created_at');
    return rows.map(Comment.fromJson).toList();
  }

  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    ensureValidCommentBody(body);
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('comments')
        .insert({
          'story_id': storyId,
          'family_id': familyId,
          'author_id': uid,
          'body': body.trim(),
        })
        .select(_select)
        .single();
    return Comment.fromJson(row);
  }

  @override
  Future<void> update({required String id, required String body}) async {
    ensureValidCommentBody(body);
    await _client.from('comments').update({'body': body.trim()}).eq('id', id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('comments').delete().eq('id', id);
  }
}

String? _authorDisplayName(Map<String, dynamic> json) {
  final author = json['author'];
  if (author is Map) {
    return author['display_name'] as String?;
  }
  return null;
}

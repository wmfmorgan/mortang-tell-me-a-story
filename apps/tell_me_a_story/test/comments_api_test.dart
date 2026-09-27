import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/comments_api.dart';

void main() {
  group('displayNameOrMember', () {
    test('returns trimmed name', () {
      expect(displayNameOrMember('Aunt Clara'), 'Aunt Clara');
      expect(displayNameOrMember('  Ada  '), 'Ada');
    });

    test('falls back to Member when missing blank or null', () {
      expect(displayNameOrMember(null), 'Member');
      expect(displayNameOrMember(''), 'Member');
      expect(displayNameOrMember('   '), 'Member');
    });
  });

  group('Comment.fromJson', () {
    test('parses nested author.display_name', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': {'display_name': 'Aunt Clara'},
      });
      expect(comment.id, 'c1');
      expect(comment.storyId, 's1');
      expect(comment.familyId, 'f1');
      expect(comment.authorId, 'u1');
      expect(comment.body, 'hi');
      expect(comment.createdAt, DateTime.parse('2026-09-27T00:00:00Z'));
      expect(comment.authorDisplayName, 'Aunt Clara');
      expect(comment.authorLabel, 'Aunt Clara');
    });

    test('authorLabel is Member when author embed is missing', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
      });
      expect(comment.authorDisplayName, isNull);
      expect(comment.authorLabel, 'Member');
    });

    test('authorLabel is Member when author is null', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': null,
      });
      expect(comment.authorLabel, 'Member');
    });

    test('authorLabel is Member when display_name is null', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': {'display_name': null},
      });
      expect(comment.authorDisplayName, isNull);
      expect(comment.authorLabel, 'Member');
    });

    test('authorLabel is Member when display_name is blank', () {
      final comment = Comment.fromJson({
        'id': 'c1',
        'story_id': 's1',
        'family_id': 'f1',
        'author_id': 'u1',
        'body': 'hi',
        'created_at': '2026-09-27T00:00:00Z',
        'author': {'display_name': '  '},
      });
      expect(comment.authorLabel, 'Member');
    });
  });

  group('ensureValidCommentBody', () {
    test('accepts non-empty body', () {
      expect(() => ensureValidCommentBody('hi'), returnsNormally);
      expect(() => ensureValidCommentBody('  hi  '), returnsNormally);
    });

    test('rejects empty body', () {
      expect(() => ensureValidCommentBody(''), throwsA(isA<ArgumentError>()));
    });

    test('rejects whitespace-only body', () {
      expect(
        () => ensureValidCommentBody('   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CommentsApi.create', () {
    test('rejects empty body before network', () {
      final api = CommentsApi(
        client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      );
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only body before network', () {
      final api = CommentsApi(
        client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      );
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: '  \n'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FakeCommentsGateway', () {
    late FakeCommentsGateway gateway;

    setUp(() {
      gateway = FakeCommentsGateway(authorId: 'u1');
    });

    test('create trims body', () async {
      final comment = await gateway.create(
        storyId: 's1',
        familyId: 'f1',
        body: '  hi  ',
      );
      expect(comment.body, 'hi');
      expect(comment.authorId, 'u1');
    });

    test('create rejects empty body before insert', () async {
      await expectLater(
        () => gateway.create(storyId: 's1', familyId: 'f1', body: '  '),
        throwsA(isA<ArgumentError>()),
      );
      expect(gateway.rows, isEmpty);
    });

    test('listForStory returns comments ordered by created_at', () async {
      gateway.rows.addAll([
        Comment(
          id: 'c-late',
          storyId: 's1',
          familyId: 'f1',
          authorId: 'u1',
          body: 'later',
          createdAt: DateTime.utc(2026, 9, 27, 2),
        ),
        Comment(
          id: 'c-early',
          storyId: 's1',
          familyId: 'f1',
          authorId: 'u1',
          body: 'earlier',
          createdAt: DateTime.utc(2026, 9, 27, 1),
        ),
        Comment(
          id: 'c-other',
          storyId: 's2',
          familyId: 'f1',
          authorId: 'u1',
          body: 'other story',
          createdAt: DateTime.utc(2026, 9, 27),
        ),
      ]);

      final listed = await gateway.listForStory('s1');
      expect(listed.map((c) => c.id), ['c-early', 'c-late']);
    });
  });
}

/// In-memory [CommentsGateway] that mirrors CommentsApi create validation.
class FakeCommentsGateway implements CommentsGateway {
  FakeCommentsGateway({required this.authorId});

  final String authorId;
  final List<Comment> rows = [];
  var _seq = 0;

  @override
  Future<List<Comment>> listForStory(String storyId) async {
    final filtered = rows.where((c) => c.storyId == storyId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered;
  }

  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    ensureValidCommentBody(body);
    final comment = Comment(
      id: 'c${++_seq}',
      storyId: storyId,
      familyId: familyId,
      authorId: authorId,
      body: body.trim(),
      createdAt: DateTime.utc(2026, 9, 27),
    );
    rows.add(comment);
    return comment;
  }

  @override
  Future<void> update({required String id, required String body}) async {
    ensureValidCommentBody(body);
    final index = rows.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final current = rows[index];
    rows[index] = Comment(
      id: current.id,
      storyId: current.storyId,
      familyId: current.familyId,
      authorId: current.authorId,
      body: body.trim(),
      createdAt: current.createdAt,
      authorDisplayName: current.authorDisplayName,
    );
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((c) => c.id == id);
  }
}

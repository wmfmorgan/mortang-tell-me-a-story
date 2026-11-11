import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/server_comments_repository.dart';
import 'package:tell_me_a_story/core/domain/comment.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _noteId = '0190d7a0-0000-7000-8000-0000000000c1';
const _storyId = '0190d7a0-0000-7000-8000-0000000000a1';
const _familyId = '0190d7a0-0000-7000-8000-0000000000f1';
const _authorId = '0190d7a0-0000-7000-8000-0000000000b1';

server.NoteDto _note({String? authorId = _authorId, String? authorName}) =>
    server.NoteDto(
      id: server.UuidValue.fromString(_noteId),
      storyId: server.UuidValue.fromString(_storyId),
      familyId: server.UuidValue.fromString(_familyId),
      kind: server.NoteKind.comment,
      authorId: authorId == null ? null : server.UuidValue.fromString(authorId),
      authorName: authorName,
      body: 'hi',
      createdAt: DateTime.utc(2026, 9, 27),
      canDelete: true,
    );

void main() {
  group('commentFromNote', () {
    test('maps ids, body, author name and canDelete', () {
      final comment = commentFromNote(_note(authorName: 'Aunt Clara'));
      expect(comment.id, _noteId);
      expect(comment.storyId, _storyId);
      expect(comment.familyId, _familyId);
      expect(comment.authorId, _authorId);
      expect(comment.body, 'hi');
      expect(comment.createdAt, DateTime.utc(2026, 9, 27));
      expect(comment.authorDisplayName, 'Aunt Clara');
      expect(comment.authorLabel, 'Aunt Clara');
      expect(comment.canDelete, isTrue);
    });

    test('authorLabel is Member when the author is gone or unnamed', () {
      final gone = commentFromNote(_note(authorId: null));
      expect(gone.authorId, isNull);
      expect(gone.authorLabel, 'Member');
      expect(commentFromNote(_note(authorName: '  ')).authorLabel, 'Member');
    });

    test('canDelete defaults to false', () {
      final comment = Comment(
        id: 'c1',
        storyId: 's1',
        familyId: 'f1',
        authorId: 'u1',
        body: 'hi',
        createdAt: DateTime.utc(2026, 9, 27),
      );
      expect(comment.canDelete, isFalse);
    });
  });

  group('ServerCommentsRepository.create', () {
    test('rejects empty body before network', () {
      final api = ServerCommentsRepository(
        client: server.Client('http://127.0.0.1:1/'),
      );
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only body before network', () {
      final api = ServerCommentsRepository(
        client: server.Client('http://127.0.0.1:1/'),
      );
      expect(
        () => api.create(storyId: 's1', familyId: 'f1', body: '  \n'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FakeCommentsRepository', () {
    late FakeCommentsRepository gateway;

    setUp(() {
      gateway = FakeCommentsRepository(authorId: 'u1');
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

/// In-memory [CommentsRepository] that mirrors ServerCommentsRepository create validation.
class FakeCommentsRepository implements CommentsRepository {
  FakeCommentsRepository({required this.authorId});

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
      canDelete: true,
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
      canDelete: current.canDelete,
    );
  }

  @override
  Future<void> delete(String id) async {
    rows.removeWhere((c) => c.id == id);
  }
}

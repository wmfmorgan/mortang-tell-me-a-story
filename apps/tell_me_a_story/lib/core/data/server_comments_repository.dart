import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/domain/comment.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';

Comment commentFromNote(server.NoteDto note) {
  return Comment(
    id: note.id.toString(),
    storyId: note.storyId.toString(),
    familyId: note.familyId.toString(),
    authorId: note.authorId?.toString(),
    body: note.body,
    createdAt: note.createdAt,
    authorDisplayName: note.authorName,
    canDelete: note.canDelete,
  );
}

/// Comments are `note` rows of kind [server.NoteKind.comment].
class ServerCommentsRepository implements CommentsRepository {
  ServerCommentsRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;
  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Comment>> listForStory(String storyId) async {
    final notes = await withServerErrors(
      () => _client.note.listForStory(
        server.UuidValue.fromString(storyId),
        kind: server.NoteKind.comment,
      ),
    );
    return notes.map(commentFromNote).toList();
  }

  /// [familyId] is the story's; the server derives it.
  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    ensureValidCommentBody(body);
    final note = await withServerErrors(
      () => _client.note.create(
        server.UuidValue.fromString(storyId),
        server.NoteKind.comment,
        body.trim(),
      ),
    );
    return commentFromNote(note);
  }

  @override
  Future<void> update({required String id, required String body}) async {
    ensureValidCommentBody(body);
    await withServerErrors(
      () => _client.note.update(server.UuidValue.fromString(id), body.trim()),
    );
  }

  @override
  Future<void> delete(String id) async {
    await withServerErrors(
      () => _client.note.delete(server.UuidValue.fromString(id)),
    );
  }
}

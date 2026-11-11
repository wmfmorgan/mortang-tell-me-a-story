import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/domain/perspective.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';

Perspective perspectiveFromNote(server.NoteDto note) {
  return Perspective(
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

/// Perspectives are `note` rows of kind [server.NoteKind.perspective].
class ServerPerspectivesRepository implements PerspectivesRepository {
  ServerPerspectivesRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;
  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Perspective>> listForStory(String storyId) async {
    final notes = await withServerErrors(
      () => _client.note.listForStory(
        server.UuidValue.fromString(storyId),
        kind: server.NoteKind.perspective,
      ),
    );
    return notes.map(perspectiveFromNote).toList();
  }

  /// [familyId] is the story's; the server derives it.
  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    ensureValidPerspectiveBody(body);
    final note = await withServerErrors(
      () => _client.note.create(
        server.UuidValue.fromString(storyId),
        server.NoteKind.perspective,
        body.trim(),
      ),
    );
    return perspectiveFromNote(note);
  }

  @override
  Future<void> update({required String id, required String body}) async {
    ensureValidPerspectiveBody(body);
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

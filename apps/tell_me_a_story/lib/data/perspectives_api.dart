import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/server/server_errors.dart';

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
    this.canDelete = false,
  });
  final String id, storyId, familyId, body;

  /// Null once the author's account is gone.
  final String? authorId;
  final DateTime createdAt;
  final String? authorDisplayName;

  /// Server-computed for the caller: the author, or a steward of the story's
  /// family on a published story (D4).
  final bool canDelete;
  String get authorLabel => displayNameOrMember(authorDisplayName);

  factory Perspective.fromNote(server.NoteDto note) {
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

/// Perspectives are `note` rows of kind [server.NoteKind.perspective].
class PerspectivesApi implements PerspectivesGateway {
  PerspectivesApi({server.Client? client}) : _injected = client;

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
    return notes.map(Perspective.fromNote).toList();
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
    return Perspective.fromNote(note);
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

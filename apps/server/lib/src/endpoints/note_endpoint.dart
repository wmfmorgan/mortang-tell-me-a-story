import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../live/live_events.dart';

/// Comments and perspectives (`story_notes`; business-rules §2.8, §4.8;
/// D4). Only the body is editable. Writes post a `note` live event after
/// commit, only while the story is published.
class NoteEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The story's notes ([kind], or both when null), oldest first. A missing
  /// or unreadable story is `NOT_FOUND: story`.
  Future<List<NoteDto>> listForStory(
    Session session,
    UuidValue storyId, {
    NoteKind? kind,
  }) async {
    final authz = Authz(session);
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await authz.canReadStory(story)) {
      throw notFound('story');
    }
    final notes = await StoryNote.db.find(
      session,
      where: (t) => kind == null
          ? t.storyId.equals(storyId)
          : t.storyId.equals(storyId) & t.kind.equals(kind),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    final rights = await _DeleteRights.of(authz, story);
    final names = await _authorNames(session, notes);
    return [for (final note in notes) _dto(note, story, names, rights)];
  }

  /// A note by the caller; needs `canContribute` on the story.
  Future<NoteDto> create(
    Session session,
    UuidValue storyId,
    NoteKind kind,
    String body,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await authz.canContribute(story)) throw forbidden();
    final note = await StoryNote.db.insertRow(
      session,
      StoryNote(storyId: storyId, authorId: uid, kind: kind, body: _body(body)),
    );
    await _post(session, story);
    return _dto(
      note,
      story,
      await _authorNames(session, [note]),
      await _DeleteRights.of(authz, story),
    );
  }

  /// Replaces the body of the caller's own note while they can contribute.
  Future<void> update(Session session, UuidValue noteId, String body) async {
    final authz = Authz(session);
    final (note, story) = await _load(session, noteId);
    if (note == null ||
        story == null ||
        note.authorId != authz.userId ||
        !await authz.canContribute(story)) {
      throw forbidden();
    }
    await StoryNote.db.updateRow(
      session,
      note.copyWith(body: _body(body), updatedAt: DateTime.now().toUtc()),
      columns: (t) => [t.body, t.updatedAt],
    );
    await _post(session, story);
  }

  /// Deletes a note: its author while they can contribute, or an owner or
  /// co-owner of the story's live family on a published story (D4).
  Future<void> delete(Session session, UuidValue noteId) async {
    final authz = Authz(session);
    final (note, story) = await _load(session, noteId);
    if (note == null ||
        story == null ||
        !(await _DeleteRights.of(authz, story)).canDelete(note)) {
      throw forbidden();
    }
    await StoryNote.db.deleteRow(session, note);
    await _post(session, story, deleted: true);
  }

  Future<(StoryNote?, Story?)> _load(Session session, UuidValue noteId) async {
    final note = await StoryNote.db.findById(session, noteId);
    if (note == null) return (null, null);
    return (note, await Story.db.findById(session, note.storyId));
  }
}

// ── helpers

/// Who may delete notes on one story (D4, schema-design §3.2): the note's
/// author while they can contribute, or an owner or co-owner of the story's
/// live family when the story is published. A child family's steward is not
/// a steward of the parent, so they can't moderate the parent's origin story.
class _DeleteRights {
  _DeleteRights(this._userId, this._canContribute, this._canModerate);

  final UuidValue? _userId;
  final bool _canContribute;
  final bool _canModerate;

  static Future<_DeleteRights> of(Authz authz, Story story) async =>
      _DeleteRights(
        authz.userId,
        await authz.canContribute(story),
        story.status == StoryStatus.published &&
            await authz.isLiveSteward(story.familyId),
      );

  bool canDelete(StoryNote note) =>
      _canModerate || (note.authorId == _userId && _canContribute);
}

NoteDto _dto(
  StoryNote note,
  Story story,
  Map<UuidValue, String?> names,
  _DeleteRights rights,
) => NoteDto(
  id: note.id!,
  storyId: note.storyId,
  familyId: story.familyId,
  kind: note.kind,
  authorId: note.authorId,
  authorName: names[note.authorId],
  body: note.body,
  createdAt: note.createdAt,
  canDelete: rights.canDelete(note),
);

/// Display names of the notes' authors, in one query.
Future<Map<UuidValue, String?>> _authorNames(
  Session session,
  List<StoryNote> notes,
) async {
  final ids = {for (final note in notes) ?note.authorId};
  if (ids.isEmpty) return {};
  final users = await AppUser.db.find(
    session,
    where: (t) => t.authUserId.inSet(ids),
  );
  return {for (final user in users) user.authUserId: user.displayName};
}

/// Trimmed body; blank is refused (CHECK `story_notes_body_not_blank`).
String _body(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) throw validation('body is required');
  return trimmed;
}

Future<void> _post(Session session, Story story, {bool deleted = false}) async {
  if (story.status != StoryStatus.published) return;
  await postLiveEvent(
    session,
    LiveEventDto(
      familyId: story.familyId,
      storyId: story.id,
      kind: LiveKind.note,
      storyStatus: story.status,
      deleted: deleted,
    ),
    treeId: story.treeId,
  );
}

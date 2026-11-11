import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../live/live_events.dart';
import '../stories/story_dates.dart';
import '../stories/story_dtos.dart';
import '../media/blob_outbox.dart';
import '../stories/story_search.dart';

/// Stories, their people tags, and search (endpoint-contract §2.2;
/// business-rules §2.5, §2.6, §4.4).
///
/// Writes post a `story` live event after commit, only while the story is
/// published (and on the publish transition); draft edits post nothing.
class StoryEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// A new draft by the caller in live [familyId]. Idempotent on [id]: when
  /// that story exists and the caller wrote it in [familyId], [input] is
  /// applied as an update and the story returned. Without [allowUndated] a
  /// start date is required.
  Future<StoryDto> createDraft(
    Session session,
    UuidValue familyId,
    StoryWriteDto input, {
    UuidValue? id,
    bool allowUndated = false,
  }) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(familyId);
    if (!allowUndated && input.dateStart == null) {
      throw validation('date required');
    }
    if (id != null && await Story.db.findById(session, id) != null) {
      return _createAgain(session, id, familyId, input);
    }
    final family = await Family.db.findById(session, familyId);
    final Story story;
    try {
      story = await session.db.transaction((t) async {
        final draft = await _applied(
          session,
          Story(
            id: id,
            familyId: familyId,
            treeId: family!.treeId,
            authorId: uid,
          ),
          input,
          t,
        );
        final row = await Story.db.insertRow(session, draft, transaction: t);
        await _replaceTags(session, row, input.personIds, t);
        return row;
      });
    } on DatabaseQueryException catch (e) {
      // A double-tapped create: the other request inserted [id] first.
      if (id == null ||
          e.code != '23505' ||
          e.constraintName != 'stories_pkey') {
        rethrow;
      }
      return _createAgain(session, id, familyId, input);
    }
    return _dto(session, story);
  }

  /// Applies [input] (null fields keep their value; a list in
  /// `personIds` replaces the tags). Author, or steward on a published story.
  Future<StoryDto> updateDraft(
    Session session,
    UuidValue storyId,
    StoryWriteDto input,
  ) async => _update(session, await _editable(session, storyId), input);

  /// Like [updateDraft], but only while the story is a draft: false once it
  /// is published, and nothing changes.
  Future<bool> autosaveDraft(
    Session session,
    UuidValue storyId,
    StoryWriteDto input,
  ) async {
    await _editable(session, storyId);
    return await _write(session, storyId, input, draftsOnly: true) != null;
  }

  /// The story when the caller may read it, else `NOT_FOUND: story`.
  Future<StoryDto> get(Session session, UuidValue storyId) async {
    final story = await _readable(session, storyId);
    if (story == null) throw notFound('story');
    return _dto(session, story);
  }

  /// Tags [personId] (same tree) on the story; a repeat is a no-op.
  Future<void> linkPerson(
    Session session,
    UuidValue storyId,
    UuidValue personId,
  ) async {
    final story = await _editable(session, storyId);
    await _requireTreePeople(session, story.treeId, {personId}, null);
    final inserted = await session.db.unsafeExecute(
      'INSERT INTO story_people ("storyId", "personId", "treeId") '
      'VALUES (@storyId::uuid, @personId::uuid, @treeId::uuid) '
      'ON CONFLICT ("storyId", "personId") DO NOTHING',
      parameters: QueryParameters.named({
        'storyId': storyId.uuid,
        'personId': personId.uuid,
        'treeId': story.treeId.uuid,
      }),
    );
    if (inserted > 0) await _postIfPublished(session, story);
  }

  /// The retried create of story [id]: the caller wrote it in [familyId].
  Future<StoryDto> _createAgain(
    Session session,
    UuidValue id,
    UuidValue familyId,
    StoryWriteDto input,
  ) async {
    final story = await Story.db.findById(session, id);
    if (story == null ||
        story.familyId != familyId ||
        story.authorId != Authz(session).userId) {
      throw forbidden();
    }
    return _update(session, story, input);
  }

  Future<StoryDto> _update(
    Session session,
    Story story,
    StoryWriteDto input,
  ) async {
    final updated = (await _write(session, story.id!, input))!;
    await _postIfPublished(session, updated);
    return _dto(session, updated);
  }

  /// Applies [input] to story [storyId] under a row lock, so a concurrent
  /// publish is never overwritten. Null when [draftsOnly] and the story is
  /// no longer a draft.
  Future<Story?> _write(
    Session session,
    UuidValue storyId,
    StoryWriteDto input, {
    bool draftsOnly = false,
  }) => session.db.transaction<Story?>((t) async {
    final story = await Story.db.findById(
      session,
      storyId,
      transaction: t,
      lockMode: LockMode.forUpdate,
    );
    if (story == null) throw forbidden();
    if (draftsOnly && story.status != StoryStatus.draft) return null;
    final next = await _applied(session, story, input, t);
    final row = await Story.db.updateRow(
      session,
      next.copyWith(updatedAt: DateTime.now().toUtc()),
      transaction: t,
    );
    await _replaceTags(session, row, input.personIds, t);
    return row;
  });

  /// [story] with [input]'s content: null fields keep the stored value, a
  /// blank title or body clears it, and `clearPlace` clears the place. Only
  /// content columns change; author, family, status and timestamps are not
  /// writable through [StoryWriteDto] (business-rules §4.4 locks).
  Future<Story> _applied(
    Session session,
    Story story,
    StoryWriteDto input,
    Transaction t,
  ) async {
    var next = story;
    if (input.dateStart != null ||
        input.dateEnd != null ||
        input.datePrecision != null) {
      final dates = normalizeStoryDates(
        input.dateStart,
        input.dateEnd,
        input.datePrecision,
      );
      next = next.copyWith(
        dateStart: dates.start,
        dateEnd: dates.end,
        datePrecision: dates.precision,
      );
    }
    if (input.title != null) next = next.copyWith(title: _text(input.title));
    if (input.body != null) next = next.copyWith(body: _text(input.body));
    if (input.clearPlace) {
      next = next.copyWith(placeId: null);
    } else if (input.placeId != null) {
      final place = await Place.db.findById(
        session,
        input.placeId!,
        transaction: t,
      );
      if (place == null || place.treeId != story.treeId) throw forbidden();
      next = next.copyWith(placeId: place.id);
    }
    return next;
  }

  /// Replaces [story]'s tags with [personIds]; null leaves them alone.
  Future<void> _replaceTags(
    Session session,
    Story story,
    List<UuidValue>? personIds,
    Transaction t,
  ) async {
    if (personIds == null) return;
    final ids = personIds.toSet();
    await _requireTreePeople(session, story.treeId, ids, t);
    await StoryPerson.db.deleteWhere(
      session,
      where: (r) => r.storyId.equals(story.id!),
      transaction: t,
    );
    if (ids.isEmpty) return;
    await StoryPerson.db.insert(session, [
      for (final id in ids)
        StoryPerson(storyId: story.id!, personId: id, treeId: story.treeId),
    ], transaction: t);
  }

  /// Every person in [ids] exists in [treeId] (business-rules §2.6: tags
  /// stay inside the story's tree); otherwise FORBIDDEN.
  Future<void> _requireTreePeople(
    Session session,
    UuidValue treeId,
    Set<UuidValue> ids,
    Transaction? t,
  ) async {
    if (ids.isEmpty) return;
    final found = await Person.db.count(
      session,
      where: (p) => p.id.inSet(ids) & p.treeId.equals(treeId),
      transaction: t,
    );
    if (found != ids.length) throw forbidden();
  }

  /// The story when the caller may edit it (`canEditStory`); a missing story
  /// is refused the same way, so ids don't leak.
  Future<Story> _editable(Session session, UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canEditStory(story)) {
      throw forbidden();
    }
    return story;
  }

  /// The story when the caller may read it (`canReadStory`), else null.
  Future<Story?> _readable(Session session, UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await Authz(session).canReadStory(story)) {
      return null;
    }
    return story;
  }

  Future<StoryDto> _dto(Session session, Story story) async =>
      (await storyDtos(session, [story])).single;

  Future<void> _postIfPublished(
    Session session,
    Story story, {
    bool deleted = false,
  }) async {
    if (story.status != StoryStatus.published) return;
    await postLiveEvent(
      session,
      LiveEventDto(
        familyId: story.familyId,
        storyId: story.id,
        kind: LiveKind.story,
        storyStatus: story.status,
        deleted: deleted,
      ),
      treeId: story.treeId,
    );
  }

  /// Publishes the caller's own draft after the readiness check. A
  /// non-author editor gets `FORBIDDEN: field is locked`. Publishing a
  /// published story returns it unchanged.
  Future<StoryDto> publish(Session session, UuidValue storyId) async {
    final story = await _editable(session, storyId);
    if (story.authorId != Authz(session).userId) {
      throw forbidden('field is locked');
    }
    final published = await session.db.transaction<Story?>((t) async {
      final row = await Story.db.findById(
        session,
        storyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (row == null) throw forbidden();
      if (row.status == StoryStatus.published) return null;
      final tagCount = await StoryPerson.db.count(
        session,
        where: (r) => r.storyId.equals(storyId),
        transaction: t,
      );
      _requireReady(row, tagCount);
      final now = DateTime.now().toUtc();
      return Story.db.updateRow(
        session,
        row.copyWith(
          status: StoryStatus.published,
          publishedAt: now,
          updatedAt: now,
        ),
        transaction: t,
      );
    });
    if (published == null) return get(session, storyId);
    await _postIfPublished(session, published);
    return _dto(session, published);
  }

  /// The story when it is published and readable by the caller, else null.
  /// Serves both the app's getPublished and getPublishedOrigin.
  Future<StoryDto?> getPublished(Session session, UuidValue storyId) async {
    final story = await _readable(session, storyId);
    if (story == null || story.status != StoryStatus.published) return null;
    return _dto(session, story);
  }

  /// The caller's drafts in live [familyId], in timeline order (undated
  /// last).
  Future<List<StoryDto>> listMyDrafts(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(familyId);
    final stories = await Story.db.find(
      session,
      where: (t) =>
          t.familyId.equals(familyId) &
          t.status.equals(StoryStatus.draft) &
          t.authorId.equals(uid),
      orderByList: _timelineOrder,
    );
    return storyDtos(session, stories);
  }

  /// [familyId]'s published stories in timeline order (schema-design §0.5).
  Future<List<StoryDto>> listPublished(
    Session session,
    UuidValue familyId,
  ) async {
    await _requireFamilyReader(session, familyId);
    final stories = await Story.db.find(
      session,
      where: (t) =>
          t.familyId.equals(familyId) & t.status.equals(StoryStatus.published),
      orderByList: _timelineOrder,
    );
    return storyDtos(session, stories);
  }

  /// Published stories of every live family in [familyId]'s tree, in
  /// timeline order (G1). A soft-deleted family's stories are left out, and
  /// it doesn't split the tree (D6b, D8). Tree readers of live [familyId]
  /// only.
  Future<List<StoryDto>> listPublishedInTree(
    Session session,
    UuidValue familyId,
  ) async {
    await _requireFamilyReader(session, familyId);
    final family = (await Family.db.findById(session, familyId))!;
    final liveFamilies = await Family.db.find(
      session,
      where: (t) => t.treeId.equals(family.treeId) & t.deletedAt.equals(null),
    );
    final stories = await Story.db.find(
      session,
      where: (t) =>
          t.treeId.equals(family.treeId) &
          t.status.equals(StoryStatus.published) &
          t.familyId.inSet(<UuidValue>{for (final f in liveFamilies) f.id!}),
      orderByList: _timelineOrder,
    );
    return storyDtos(session, stories);
  }

  /// Published in the last [withinDays] days, newest first (`latestOrder`),
  /// at most [limit].
  Future<List<StoryDto>> listLatestPublished(
    Session session,
    UuidValue familyId, {
    int withinDays = 7,
    int limit = 3,
  }) async {
    await _requireFamilyReader(session, familyId);
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: withinDays));
    final stories = await Story.db.find(
      session,
      where: (t) =>
          t.familyId.equals(familyId) &
          t.status.equals(StoryStatus.published) &
          (t.publishedAt >= cutoff),
      orderByList: (t) => [t.publishedAt.desc(), t.id.desc()],
      limit: limit,
    );
    return storyDtos(session, stories);
  }

  /// Published stories in live families of the person's tree that tag
  /// [personId], oldest first. A person outside the caller's tree is
  /// `NOT_FOUND: person`.
  Future<List<StoryDto>> listForPerson(
    Session session,
    UuidValue personId,
  ) async {
    final person = await Person.db.findById(session, personId);
    if (person == null || !await Authz(session).isTreeMemberOf(person.treeId)) {
      throw notFound('person');
    }
    final tags = await StoryPerson.db.find(
      session,
      where: (t) => t.personId.equals(personId),
    );
    if (tags.isEmpty) return [];
    final liveFamilies = await Family.db.find(
      session,
      where: (t) => t.treeId.equals(person.treeId) & t.deletedAt.equals(null),
    );
    final stories = await Story.db.find(
      session,
      where: (t) =>
          t.id.inSet(<UuidValue>{for (final tag in tags) tag.storyId}) &
          t.status.equals(StoryStatus.published) &
          t.familyId.inSet(<UuidValue>{for (final f in liveFamilies) f.id!}),
      orderByList: _timelineOrder,
    );
    return storyDtos(session, stories);
  }

  /// Published stories of [familyId] are readable by its live members and
  /// tree readers (business-rules §2.5); everyone else is FORBIDDEN.
  Future<void> _requireFamilyReader(
    Session session,
    UuidValue familyId,
  ) async {
    if (!await Authz(session).isTreeReadable(familyId)) throw forbidden();
  }

  /// Deletes the caller's own story (any status) with its photos, notes and
  /// tags. Owners can't delete other people's stories (D4). Photo blob keys
  /// are queued for deletion in the same transaction.
  Future<void> discard(Session session, UuidValue storyId) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final story = await Story.db.findById(session, storyId);
    if (story == null ||
        story.authorId != uid ||
        !await authz.isLiveMember(story.familyId)) {
      throw forbidden();
    }
    final deleted = await session.db.transaction<Story?>((t) async {
      final row = await Story.db.findById(
        session,
        storyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (row == null) return null;
      final photos = await Photo.db.find(
        session,
        where: (p) => p.storyId.equals(storyId),
        transaction: t,
      );
      await queueBlobDeletions(session, [
        for (final photo in photos) ...[photo.originalKey, photo.editedKey],
      ], transaction: t);
      await Story.db.deleteRow(session, row, transaction: t);
      return row;
    });
    if (deleted != null) {
      await _postIfPublished(session, deleted, deleted: true);
    }
  }

  /// Published stories of `q.familyId` matching [q] (endpoint-contract §2.2
  /// search semantics). Live members and tree readers only.
  Future<List<StoryDto>> search(Session session, StorySearchDto q) async {
    await _requireFamilyReader(session, q.familyId);
    final ids = await searchStoryIds(session, q);
    if (ids.isEmpty) return [];
    final rows = await Story.db.find(
      session,
      where: (t) => t.id.inSet(ids.toSet()),
    );
    final byId = {for (final story in rows) story.id!: story};
    return storyDtos(session, [for (final id in ids) ?byId[id]]);
  }

  /// Decade, person and place facets over [familyId]'s published stories.
  Future<StoryFacetsDto> facets(Session session, UuidValue familyId) async {
    await _requireFamilyReader(session, familyId);
    return storyFacets(session, familyId);
  }
}

// ── helpers

/// Trimmed; blank → null, so a saved title or body can be cleared.
String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// `timelineOrder` (schema-design §0.5): dateStart, datePrecision,
/// createdAt, id ascending. Undated drafts sort last (Postgres ASC puts
/// NULLs last).
List<Order> _timelineOrder(StoryTable t) => [
  t.dateStart.asc(),
  t.datePrecision.asc(),
  t.createdAt.asc(),
  t.id.asc(),
];

/// The app's publish readiness (`publishReadiness` in stories_api.dart), on
/// the server. The date comes first: it is the business-rules §4.4 rule. A
/// place is optional.
void _requireReady(Story story, int tagCount) {
  if (story.dateStart == null) throw validation('date required');
  if ((story.title ?? '').trim().isEmpty) throw validation('title required');
  if ((story.body ?? '').trim().isEmpty) throw validation('body required');
  if (tagCount == 0) throw validation('person required');
}

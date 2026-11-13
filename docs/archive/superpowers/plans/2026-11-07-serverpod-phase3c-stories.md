# Phase 3c: Stories, Tags, Notes, Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `StoryEndpoint` (all methods in endpoint-contract §2.2, including `search` and `facets`) and `NoteEndpoint` on Serverpod 4.1.1, tested against business-rules §7 cases 26–28 (story/comment/perspective part), 43–45, 62–77, 83 (comment/perspective part), 93, 94 and 137 (story part).

**Architecture:** Two endpoint classes under `apps/server/lib/src/endpoints/`, built on the landed 3.0 foundation (`Authz`, `errors.dart`, `queueBlobDeletions`, `postLiveEvent`, DTOs). Story-specific helpers live in `apps/server/lib/src/stories/`: date normalization (pure), `StoryDto` assembly with a fixed number of queries per call (no N+1), and the search/facet SQL. Writes run in one transaction under a story row lock; live events are posted after commit, only for published stories (and the publish transition).

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1, embedded Postgres 16, just.

**Spec of record:** Phase 3 index row "3c" and §Conventions (`2026-11-07-serverpod-phase3-server-endpoints.md`); business-rules §2.5, §2.6, §2.8, §4.4, §4.8, §7; schema-design §0.5 (named orders), §3.2 (story locks, notes body-only, notes delete D4); endpoint-contract §2.1–§2.2 (signatures and search semantics); roadmap decisions D4, D6b, D9.

All commands run from the worktree root unless a step says otherwise.

---

## Decisions taken inside the slice

These fill gaps the spec leaves open. None changes a schema, a DTO or another slice's endpoint.

| Topic | Choice | Why |
|---|---|---|
| Unreadable or missing story on a **read** (`get`, `note.listForStory`) | `NOT_FOUND: story` for both | Same answer either way, so ids don't leak; `getPublished` returns null instead |
| Unreadable or missing story on a **write** | `FORBIDDEN` (default message) for both | §Conventions: refuse missing like a stranger |
| Family-scoped lists (`listMyDrafts`) | `requireLiveMember` → `FORBIDDEN: member only` | §Conventions D6b |
| Published lists, search, facets | `Authz.isTreeReadable(familyId)` (live member or tree reader) else `FORBIDDEN` | business-rules §2.5 "Read published" |
| `listForPerson` on a person outside the caller's tree | `NOT_FOUND: person` | matches `people.profile` (business-rules case 98) |
| Date shape violations (business-rules §4.4) | `VALIDATION: invalid date` | §5.2 has no string; the old app surfaced the raw CHECK failure as "Try again" |
| `decade` precision (case 66) | Gone from `DatePrecision` (D9); a decade-wide span with year precision is refused as `invalid date` | the case's intent: decade can't be stored |
| `publish` readiness | Server runs the app's `publishReadiness` (title, body, date, ≥1 person, place). Date first: `date required` (§4.4); then `title required`, `body required`, `person required`, `place required` | endpoint-contract: "server checks readiness → VALIDATION" |
| Non-author editor calls `publish` | `FORBIDDEN: field is locked` (case 72) | business-rules §2.5 |
| Note body | trimmed; blank → `VALIDATION: body is required` | DB CHECK `story_notes_body_not_blank`; no catalogue string |
| Tagging a person / using a place outside the story's tree (or missing) | `FORBIDDEN` | business-rules §2.6: same tree is an authorization rule |
| Unpublish | No endpoint method exists (contract §2.2 has none, the app has no caller). Tests that need an unpublished story set the row directly | contract wins |
| Defaulted named parameters (`allowUndated = false`, `withinDays = 7`, `limit = 3`) | Server signatures match the contract exactly, but Serverpod 4.1.1 generates them as `required` named parameters in the client and test tools, so tests (and Phase 4 callers) pass them explicitly | generator behaviour, not a contract change |
| Locked columns (cases 72, 73, 94) | Structural: `StoryWriteDto` and `note.update` carry no author/family/status/createdAt; tests assert they are unchanged after edits | there is no API to send them |

## File map

| Path | Responsibility |
|---|---|
| `apps/server/lib/src/stories/story_dates.dart` | `normalizeStoryDates`: client dates → stored shape (business-rules §4.4) |
| `apps/server/lib/src/stories/story_dtos.dart` | `storyDtos`: `Story` rows → `StoryDto`s in 6 queries (tags+people, photos, places, authors, note counts) |
| `apps/server/lib/src/stories/story_search.dart` | `searchStoryIds` and `storyFacets`: parameterized SQL for endpoint-contract search semantics |
| `apps/server/lib/src/endpoints/story_endpoint.dart` | `StoryEndpoint` (14 methods) |
| `apps/server/lib/src/endpoints/note_endpoint.dart` | `NoteEndpoint` (4 methods) with `NoteDto.canDelete` (D4) |
| `apps/server/test/unit/story_dates_test.dart` | Date normalization cases 62, 64–66 |
| `apps/server/test/integration/support/stories_fixtures.dart` | Slice builders: `StoryFx` (notes, photos, origin, status, soft delete, profile), `Clan`, `Branch`, `write`, `liveEvents`, `settle` |
| `apps/server/test/integration/story_dtos_test.dart` | `storyDtos` field coverage |
| `apps/server/test/integration/story_endpoint_test.dart` | `StoryEndpoint` behaviour |
| `apps/server/test/integration/note_endpoint_test.dart` | `NoteEndpoint` behaviour |
| generated: `lib/src/generated/endpoints.dart`, `test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart` | `just server-generate` output |

Code blocks are annotated with an HTML comment saying where they go: `create` (new file), `import` (after the last import line), `class` (before the class's closing `}`, which is the last `}` line of the file before any top-level functions marked `// ── helpers`), `top` (end of file), `tests` (before the final `  }, rollbackDatabase: RollbackDatabase.disabled);` line).

---

### Task 1: Date normalization

**Files:**
- Create: `apps/server/lib/src/stories/story_dates.dart`
- Test: `apps/server/test/unit/story_dates_test.dart`

- [ ] **Step 1: Write the failing test**

<!-- file: apps/server/test/unit/story_dates_test.dart mode: create -->
```dart
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/stories/story_dates.dart';
import 'package:test/test.dart';

Matcher throwsValidation(String message) => throwsA(
  isA<AppException>()
      .having((e) => e.code, 'code', AppErrorCode.validation)
      .having((e) => e.message, 'message', message),
);

void main() {
  group('normalizeStoryDates', () {
    // BR 62
    test('Given no dates, then the draft stays undated', () {
      final d = normalizeStoryDates(null, null, null);
      expect((d.start, d.end, d.precision), (null, null, null));
    });

    // BR 64
    test(
      'Given a start with null end and precision, then end = start and precision day',
      () {
        final d = normalizeStoryDates(DateTime.utc(1950, 6, 3), null, null);
        expect(d.start, DateTime.utc(1950, 6, 3));
        expect(d.end, DateTime.utc(1950, 6, 3));
        expect(d.precision, DatePrecision.day);
      },
    );

    test('Given month and year precision, then the end closes the span', () {
      expect(
        normalizeStoryDates(
          DateTime.utc(1952, 2),
          null,
          DatePrecision.month,
        ).end,
        DateTime.utc(1952, 2, 29),
      );
      expect(
        normalizeStoryDates(
          DateTime.utc(1950),
          DateTime.utc(1950, 12, 31),
          DatePrecision.year,
        ).end,
        DateTime.utc(1950, 12, 31),
      );
    });

    // BR 65
    test(
      'Given day with differing end / month not on 1st / year not full / '
      'year outside 1000–9999 / time of day, then rejected',
      () {
        final bad = <(DateTime, DateTime?, DatePrecision?)>[
          (
            DateTime.utc(1950, 6, 3),
            DateTime.utc(1950, 6, 4),
            DatePrecision.day,
          ),
          (DateTime.utc(1950, 6, 3), DateTime.utc(1950, 6, 9), null),
          (DateTime.utc(1950, 6, 3), null, DatePrecision.month),
          (
            DateTime.utc(1950, 6),
            DateTime.utc(1950, 7, 31),
            DatePrecision.month,
          ),
          (DateTime.utc(1950, 6), null, DatePrecision.year),
          (DateTime.utc(1950), DateTime.utc(1950, 6, 30), DatePrecision.year),
          (DateTime.utc(999), null, DatePrecision.year),
          (DateTime.utc(10000), null, DatePrecision.year),
          (DateTime.utc(1950, 6, 3, 12), null, null),
        ];
        for (final (start, end, precision) in bad) {
          expect(
            () => normalizeStoryDates(start, end, precision),
            throwsValidation(invalidDateMessage),
            reason: '$start $end $precision',
          );
        }
      },
    );

    // BR 66 (decade precision dropped, D9)
    test('Given a decade-wide span, then rejected', () {
      expect(
        () => normalizeStoryDates(
          DateTime.utc(1950),
          DateTime.utc(1959, 12, 31),
          DatePrecision.year,
        ),
        throwsValidation(invalidDateMessage),
      );
    });

    test(
      'Given an end or precision without a start, then VALIDATION "date required"',
      () {
        expect(
          () => normalizeStoryDates(null, DateTime.utc(1950), null),
          throwsValidation('date required'),
        );
        expect(
          () => normalizeStoryDates(null, null, DatePrecision.year),
          throwsValidation('date required'),
        );
      },
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/unit/story_dates_test.dart`
Expected: FAIL to load: `story_dates.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

<!-- file: apps/server/lib/src/stories/story_dates.dart mode: create -->
```dart
import '../errors.dart';
import '../generated/protocol.dart';

/// A date span the timeline can't store (business-rules §4.4, CHECK
/// `stories_date_shape`). §5.2 has no catalogue string for it; the old app
/// surfaced the raw CHECK failure as "Try again".
const invalidDateMessage = 'invalid date';

/// A story's stored dates: all null (undated draft) or a full span.
typedef StoryDates = ({
  DateTime? start,
  DateTime? end,
  DatePrecision? precision,
});

/// Normalizes client dates to the stored shape (business-rules §4.4):
/// - no start: undated; an end or a precision alone is `date required`;
/// - no precision: `day` when the end is missing or equals the start;
/// - the end is derived from start + precision (schema-design §0.5), and a
///   client end that differs is refused;
/// - the start is UTC midnight, aligned to its precision, in 1000–9999.
StoryDates normalizeStoryDates(
  DateTime? start,
  DateTime? end,
  DatePrecision? precision,
) {
  if (start == null) {
    if (end != null || precision != null) throw validation('date required');
    return (start: null, end: null, precision: null);
  }
  final from = _calendarDay(start);
  final to = end == null ? null : _calendarDay(end);
  final p =
      precision ??
      (to == null || to == from
          ? DatePrecision.day
          : throw validation(invalidDateMessage));
  if (from.year < 1000 || from.year > 9999) {
    throw validation(invalidDateMessage);
  }
  final derivedEnd = switch (p) {
    DatePrecision.day => from,
    DatePrecision.month when from.day == 1 => DateTime.utc(
      from.year,
      from.month + 1,
      0,
    ),
    DatePrecision.year when from.month == 1 && from.day == 1 => DateTime.utc(
      from.year,
      12,
      31,
    ),
    _ => throw validation(invalidDateMessage),
  };
  if (to != null && to != derivedEnd) throw validation(invalidDateMessage);
  return (start: from, end: derivedEnd, precision: p);
}

/// [value] as a UTC calendar day; a time of day is refused.
DateTime _calendarDay(DateTime value) {
  final utc = value.toUtc();
  final day = DateTime.utc(utc.year, utc.month, utc.day);
  if (utc != day) throw validation(invalidDateMessage);
  return day;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/unit/story_dates_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/stories/story_dates.dart apps/server/test/unit/story_dates_test.dart
git commit -m "feat(server): story date normalization"
```

---

### Task 2: Story DTO assembly and slice fixtures

**Files:**
- Create: `apps/server/lib/src/stories/story_dtos.dart`
- Create: `apps/server/test/integration/support/stories_fixtures.dart`
- Test: `apps/server/test/integration/story_dtos_test.dart`

- [ ] **Step 1: Write the slice fixtures**

<!-- file: apps/server/test/integration/support/stories_fixtures.dart mode: create -->
```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';

import 'fixtures.dart';

/// Slice 3c row builders on top of [Fx].
extension StoryFx on Fx {
  /// Sets [user]'s app profile name and avatar key.
  Future<void> profile(
    UuidValue user, {
    String? displayName,
    String? avatarKey,
  }) async {
    final row = await AppUser.db.findFirstRow(
      s,
      where: (t) => t.authUserId.equals(user),
    );
    await AppUser.db.updateRow(
      s,
      row!.copyWith(displayName: displayName, avatarKey: avatarKey),
    );
  }

  Future<StoryNote> note(
    Story story,
    UuidValue author, {
    NoteKind kind = NoteKind.comment,
    String body = 'Lovely',
  }) => StoryNote.db.insertRow(
    s,
    StoryNote(storyId: story.id!, authorId: author, kind: kind, body: body),
  );

  /// A photo row on [story]; no blob is uploaded.
  Future<Photo> photo(Story story, {int sortOrder = 0, String? editedKey}) {
    final photoId = UuidValue.fromString(const Uuid().v7());
    return Photo.db.insertRow(
      s,
      Photo(
        id: photoId,
        storyId: story.id!,
        originalKey:
            'families/${story.familyId}/stories/${story.id}/photos/$photoId/original.jpg',
        editedKey: editedKey,
        editVersion: editedKey == null ? 0 : 1,
        sortOrder: sortOrder,
      ),
    );
  }

  /// Points [child]'s origin at [story] (setOrigin itself is slice 3a).
  Future<Family> origin(Family child, Story story) =>
      Family.db.updateRow(s, child.copyWith(originStoryId: story.id));

  /// Moves [story] to [status] directly, as an unpublish would.
  Future<Story> setStatus(Story story, StoryStatus status) =>
      Story.db.updateRow(
        s,
        story.copyWith(
          status: status,
          publishedAt: status == StoryStatus.published
              ? DateTime.now().toUtc()
              : null,
        ),
      );

  Future<Family> softDelete(Family family) => Family.db.updateRow(
    s,
    family.copyWith(deletedAt: DateTime.now().toUtc()),
  );
}

/// Story input; null fields leave the story alone.
StoryWriteDto write({
  DateTime? dateStart,
  DateTime? dateEnd,
  DatePrecision? datePrecision,
  String? title,
  String? body,
  UuidValue? placeId,
  bool clearPlace = false,
  List<UuidValue>? personIds,
}) => StoryWriteDto(
  dateStart: dateStart,
  dateEnd: dateEnd,
  datePrecision: datePrecision,
  title: title,
  body: body,
  placeId: placeId,
  clearPlace: clearPlace,
  personIds: personIds,
);

/// One live family with every role, plus a stranger in no family.
class Clan {
  Clan._(
    this.fx,
    this.tree,
    this.family, {
    required this.owner,
    required this.coOwner,
    required this.member,
    required this.author,
    required this.stranger,
  });

  final Fx fx;
  final Tree tree;
  final Family family;
  final UuidValue owner, coOwner, member, author, stranger;

  static Future<Clan> of(Fx fx) async {
    final tree = await fx.tree();
    final family = await fx.family(tree);
    final owner = await fx.user();
    final coOwner = await fx.user();
    final member = await fx.user();
    final author = await fx.user();
    final stranger = await fx.user();
    await fx.join(family, owner, MembershipRole.owner);
    await fx.join(family, coOwner, MembershipRole.coOwner);
    await fx.join(family, member);
    await fx.join(family, author);
    return Clan._(
      fx,
      tree,
      family,
      owner: owner,
      coOwner: coOwner,
      member: member,
      author: author,
      stranger: stranger,
    );
  }

  /// A published 1950 story by [author].
  Future<Story> published() => fx.story(family, authorId: author);

  /// A dated draft by [author].
  Future<Story> draft() =>
      fx.story(family, authorId: author, status: StoryStatus.draft);

  /// A live child branch of [family] with an owner and a member; its origin
  /// is [origin] when given.
  Future<Branch> branch({Story? origin}) async {
    var child = await fx.family(
      tree,
      parentId: family.id,
      branchYear: 1980,
      name: 'Branch',
    );
    if (origin != null) child = await fx.origin(child, origin);
    final owner = await fx.user();
    final member = await fx.user();
    await fx.join(child, owner, MembershipRole.owner);
    await fx.join(child, member);
    return Branch(child, owner: owner, member: member);
  }

  /// Input that passes publish readiness: dated, titled, with a body, a
  /// tagged person and a place.
  Future<StoryWriteDto> ready() async {
    final person = await fx.person(family);
    final place = await fx.place(tree);
    return write(
      dateStart: DateTime.utc(1950),
      datePrecision: DatePrecision.year,
      title: 'Title',
      body: 'Body',
      placeId: place.id,
      personIds: [person.id!],
    );
  }
}

class Branch {
  Branch(this.family, {required this.owner, required this.member});

  final Family family;
  final UuidValue owner, member;
}

/// Every [LiveEventDto] posted to [channel] from now on.
List<LiveEventDto> liveEvents(Session session, String channel) {
  final events = <LiveEventDto>[];
  session.messages.addListener(channel, (message) {
    if (message is LiveEventDto) events.add(message);
  });
  return events;
}

/// Gives local message delivery a moment.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));
```

- [ ] **Step 2: Write the failing test**

<!-- file: apps/server/test/integration/story_dtos_test.dart mode: create -->
```dart
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/stories/story_dtos.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/stories_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given stories with tags, photos, a place and notes', (
    sessionBuilder,
    endpoints,
  ) {
    test(
      'when assembled then every field is filled, photo keys are effective '
      'and notes are counted per kind',
      () async {
        final session = sessionBuilder.build();
        final fx = Fx(session);
        final author = await fx.user();
        await fx.profile(
          author,
          displayName: 'Ann',
          avatarKey: 'users/$author/avatar/a.jpg',
        );
        final tree = await fx.tree();
        final family = await fx.family(tree);
        final place = await fx.place(tree);
        final zoe = await fx.person(family, name: 'Zoe');
        final abe = await fx.person(family, name: 'Abe', userId: author);
        final story = await fx.story(
          family,
          authorId: author,
          placeId: place.id,
        );
        final bare = await fx.story(family, status: StoryStatus.draft);
        await fx.tag(story, zoe);
        await fx.tag(story, abe);
        final second = await fx.photo(story, sortOrder: 1);
        await fx.photo(story, editedKey: 'edited-1.jpg');
        await fx.note(story, author);
        await fx.note(story, author);
        await fx.note(story, author, kind: NoteKind.perspective);

        final dtos = await storyDtos(session, [story, bare]);

        expect(dtos.map((d) => d.id), [story.id, bare.id]);
        final dto = dtos.first;
        expect(dto.familyId, family.id);
        expect(dto.authorId, author);
        expect(dto.title, 'A story');
        expect(dto.dateStart, DateTime.utc(1950));
        expect(dto.dateEnd, DateTime.utc(1950, 12, 31));
        expect(dto.datePrecision, DatePrecision.year);
        expect(dto.status, StoryStatus.published);
        expect(dto.publishedAt, isNotNull);
        expect(dto.people.map((p) => p.name), ['Abe', 'Zoe']);
        expect(dto.people.first.userId, author);
        expect(dto.people.last.userId, isNull);
        expect(dto.photos.map((p) => p.key), [
          'edited-1.jpg',
          second.originalKey,
        ]);
        expect(dto.photos.map((p) => p.sortOrder), [0, 1]);
        expect(dto.placeId, place.id);
        expect(dto.placeLabel, 'Home');
        expect(dto.placeAddress, '1 Main St');
        expect(dto.authorName, 'Ann');
        expect(dto.authorAvatarKey, 'users/$author/avatar/a.jpg');
        expect(dto.commentCount, 2);
        expect(dto.perspectiveCount, 1);

        final empty = dtos.last;
        expect(empty.people, isEmpty);
        expect(empty.photos, isEmpty);
        expect(empty.placeLabel, isNull);
        expect(empty.authorName, isNull);
        expect(empty.commentCount, 0);
        expect(empty.perspectiveCount, 0);
        expect(await storyDtos(session, []), isEmpty);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/story_dtos_test.dart`
Expected: FAIL to load: `story_dtos.dart` doesn't exist.

- [ ] **Step 4: Write the implementation**

<!-- file: apps/server/lib/src/stories/story_dtos.dart mode: create -->
```dart
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// [stories] as [StoryDto]s, in the same order. The query count is fixed
/// (tags, people, photos, places, authors, note counts), whatever the number
/// of stories, so list endpoints never fan out per story.
Future<List<StoryDto>> storyDtos(Session session, List<Story> stories) async {
  if (stories.isEmpty) return [];
  final storyIds = {for (final story in stories) story.id!};

  final tags = await StoryPerson.db.find(
    session,
    where: (t) => t.storyId.inSet(storyIds),
  );
  final storiesByPerson = <UuidValue, List<UuidValue>>{};
  for (final tag in tags) {
    (storiesByPerson[tag.personId] ??= []).add(tag.storyId);
  }
  final people = storiesByPerson.isEmpty
      ? <Person>[]
      : await Person.db.find(
          session,
          where: (t) => t.id.inSet(storiesByPerson.keys.toSet()),
          orderByList: (t) => [t.name.asc(), t.id.asc()],
        );
  final peopleByStory = <UuidValue, List<StoryPersonDto>>{};
  for (final person in people) {
    for (final storyId in storiesByPerson[person.id]!) {
      (peopleByStory[storyId] ??= []).add(
        StoryPersonDto(
          personId: person.id!,
          name: person.name,
          userId: person.userId,
        ),
      );
    }
  }

  final photos = await Photo.db.find(
    session,
    where: (t) => t.storyId.inSet(storyIds),
    orderByList: (t) => [t.sortOrder.asc(), t.createdAt.asc(), t.id.asc()],
  );
  final photosByStory = <UuidValue, List<PhotoRefDto>>{};
  for (final photo in photos) {
    (photosByStory[photo.storyId] ??= []).add(
      PhotoRefDto(
        id: photo.id!,
        key: photo.editedKey ?? photo.originalKey,
        sortOrder: photo.sortOrder,
      ),
    );
  }

  final placeIds = {for (final story in stories) ?story.placeId};
  final places = placeIds.isEmpty
      ? <Place>[]
      : await Place.db.find(session, where: (t) => t.id.inSet(placeIds));
  final placeById = {for (final place in places) place.id!: place};

  final authorIds = {for (final story in stories) ?story.authorId};
  final authors = authorIds.isEmpty
      ? <AppUser>[]
      : await AppUser.db.find(
          session,
          where: (t) => t.authUserId.inSet(authorIds),
        );
  final authorById = {for (final user in authors) user.authUserId: user};

  final counts = await _noteCounts(session, storyIds);

  return [
    for (final story in stories)
      StoryDto(
        id: story.id!,
        familyId: story.familyId,
        authorId: story.authorId,
        title: story.title,
        body: story.body,
        dateStart: story.dateStart,
        dateEnd: story.dateEnd,
        datePrecision: story.datePrecision,
        createdAt: story.createdAt,
        placeId: story.placeId,
        placeLabel: placeById[story.placeId]?.label,
        placeAddress: placeById[story.placeId]?.address,
        status: story.status,
        publishedAt: story.publishedAt,
        people: peopleByStory[story.id] ?? [],
        photos: photosByStory[story.id] ?? [],
        authorName: authorById[story.authorId]?.displayName,
        authorAvatarKey: authorById[story.authorId]?.avatarKey,
        commentCount: counts[(story.id!, NoteKind.comment)] ?? 0,
        perspectiveCount: counts[(story.id!, NoteKind.perspective)] ?? 0,
      ),
  ];
}

/// Note counts per (story, kind), in one grouped query.
Future<Map<(UuidValue, NoteKind), int>> _noteCounts(
  Session session,
  Set<UuidValue> storyIds,
) async {
  final rows = await session.db.unsafeQuery(
    'SELECT "storyId"::text, "kind", count(*)::int FROM story_notes '
    'WHERE "storyId" = ANY(@ids::uuid[]) GROUP BY "storyId", "kind"',
    parameters: QueryParameters.named({
      'ids': [for (final id in storyIds) id.uuid],
    }),
  );
  return {
    for (final row in rows)
      (
        UuidValue.fromString(row[0] as String),
        NoteKind.fromJson(row[1] as String),
      ): row[2] as int,
  };
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apps/server && mise exec -- dart test test/integration/story_dtos_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/stories/story_dtos.dart apps/server/test/integration/support/stories_fixtures.dart apps/server/test/integration/story_dtos_test.dart
git commit -m "feat(server): story DTO assembly without per-story queries"
```

---

### Task 3: StoryEndpoint drafting, editing and tags

`createDraft`, `updateDraft`, `autosaveDraft`, `get`, `linkPerson`. Covers BR 62, 64–66 (through the endpoint), 71, 72 (locked columns), 73, 75–77 and the live-event rule for edits.

**Files:**
- Create: `apps/server/lib/src/endpoints/story_endpoint.dart`
- Test: `apps/server/test/integration/story_endpoint_test.dart`
- Generated: `apps/server/lib/src/generated/endpoints.dart`, `apps/server/test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart`

- [ ] **Step 1: Write the failing test**

<!-- file: apps/server/test/integration/story_endpoint_test.dart mode: create -->
```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:tell_me_a_story_server/src/stories/story_dates.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/stories_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given StoryEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late Clan c;
    TestSessionBuilder by(UuidValue user) => asUser(sessionBuilder, user);
    UuidValue newId() => UuidValue.fromString(const Uuid().v7());

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      c = await Clan.of(fx);
    });

    test('when an anonymous caller reads a story then it is refused', () async {
      final story = await c.published();
      await expectLater(
        endpoints.story.get(sessionBuilder, story.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    group('creating drafts', () {
      // BR 62
      test(
        'when a member saves a draft with null dates then start, end and '
        'precision are stored null',
        () async {
          final dto = await endpoints.story.createDraft(
            by(c.member),
            c.family.id!,
            write(title: ' Undated '),
            allowUndated: true,
          );
          expect(
            (dto.dateStart, dto.dateEnd, dto.datePrecision),
            (
              null,
              null,
              null,
            ),
          );
          expect(dto.status, StoryStatus.draft);
          expect(dto.authorId, c.member);
          expect(dto.title, 'Undated');
          final row = await Story.db.findById(fx.s, dto.id);
          expect(row!.dateStart, isNull);
          expect(row.treeId, c.tree.id);
        },
      );

      test(
        'when a draft has no start and allowUndated is false then VALIDATION '
        '"date required"',
        () async {
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(title: 'x'),
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.validation, 'date required'),
          );
        },
      );

      // BR 64
      test(
        'when a draft has a start with null end then end = start and precision day',
        () async {
          final dto = await endpoints.story.createDraft(
            by(c.member),
            c.family.id!,
            write(dateStart: DateTime.utc(1950, 6, 3)),
            allowUndated: false,
          );
          expect(dto.dateEnd, DateTime.utc(1950, 6, 3));
          expect(dto.datePrecision, DatePrecision.day);
        },
      );

      // BR 65
      test(
        'when a month draft does not start on the 1st then VALIDATION',
        () async {
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(
                dateStart: DateTime.utc(1950, 6, 3),
                datePrecision: DatePrecision.month,
              ),
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.validation, invalidDateMessage),
          );
        },
      );

      // BR 66
      test(
        'when a draft spans a decade then VALIDATION (decade precision is '
        'dropped, D9)',
        () async {
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(
                dateStart: DateTime.utc(1950),
                dateEnd: DateTime.utc(1959, 12, 31),
                datePrecision: DatePrecision.year,
              ),
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.validation, invalidDateMessage),
          );
        },
      );

      test(
        'when a stranger, or a member of a soft-deleted family, creates a '
        'draft then FORBIDDEN "member only"',
        () async {
          final input = write(dateStart: DateTime.utc(1950));
          await expectLater(
            endpoints.story.createDraft(
              by(c.stranger),
              c.family.id!,
              input,
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          await fx.softDelete(c.family);
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              input,
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
          expect(
            await Story.db.count(
              fx.s,
              where: (t) => t.familyId.equals(c.family.id!),
            ),
            0,
          );
        },
      );

      test(
        'when the same id is created twice then there is one draft with the '
        'second input',
        () async {
          final id = newId();
          await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(title: 'First', dateStart: DateTime.utc(1950)),
            id: id,
            allowUndated: false,
          );
          final again = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(title: 'Second', dateStart: DateTime.utc(1950)),
            id: id,
            allowUndated: false,
          );
          expect(again.id, id);
          expect(again.title, 'Second');
          expect(await Story.db.count(fx.s, where: (t) => t.id.equals(id)), 1);
        },
      );

      test(
        'when two creates with the same id race then one draft exists',
        () async {
          final id = newId();
          final input = write(title: 'Twice', dateStart: DateTime.utc(1950));
          final results = await Future.wait([
            endpoints.story.createDraft(
              by(c.author),
              c.family.id!,
              input,
              id: id,
              allowUndated: false,
            ),
            endpoints.story.createDraft(
              by(c.author),
              c.family.id!,
              input,
              id: id,
              allowUndated: false,
            ),
          ]);
          expect(results.map((d) => d.id).toSet(), {id});
          expect(await Story.db.count(fx.s, where: (t) => t.id.equals(id)), 1);
        },
      );

      test(
        'when another member retries a create with an existing id then '
        'FORBIDDEN and the story is unchanged',
        () async {
          final id = newId();
          final input = write(title: 'Mine', dateStart: DateTime.utc(1950));
          await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            input,
            id: id,
            allowUndated: false,
          );
          await expectLater(
            endpoints.story.createDraft(
              by(c.member),
              c.family.id!,
              write(title: 'Theirs', dateStart: DateTime.utc(1950)),
              id: id,
              allowUndated: false,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect((await Story.db.findById(fx.s, id))!.title, 'Mine');
        },
      );

      test(
        'when a draft names people and a place then the story carries them once',
        () async {
          final person = await fx.person(c.family, name: 'Ada');
          final place = await fx.place(c.tree);
          final dto = await endpoints.story.createDraft(
            by(c.member),
            c.family.id!,
            write(
              dateStart: DateTime.utc(1950),
              placeId: place.id,
              personIds: [person.id!, person.id!],
            ),
            allowUndated: false,
          );
          expect(dto.people.map((p) => p.personId), [person.id]);
          expect(dto.placeLabel, 'Home');
        },
      );
    });

    group('editing', () {
      test(
        'when updating, null fields stay, a blank title clears and clearPlace '
        'clears the place',
        () async {
          final place = await fx.place(c.tree);
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(
              dateStart: DateTime.utc(1950),
              title: 'T',
              body: 'B',
              placeId: place.id,
            ),
            allowUndated: false,
          );
          final dto = await endpoints.story.updateDraft(
            by(c.author),
            draft.id,
            write(title: '  ', clearPlace: true),
          );
          expect(dto.title, isNull);
          expect(dto.body, 'B');
          expect(dto.placeId, isNull);
          expect(dto.dateStart, DateTime.utc(1950));
        },
      );

      // BR 71
      test(
        'when the author edits their draft and their published story then '
        'both change',
        () async {
          final draft = await c.draft();
          final published = await c.published();
          for (final story in [draft, published]) {
            final dto = await endpoints.story.updateDraft(
              by(c.author),
              story.id!,
              write(title: 'Edited', dateStart: DateTime.utc(1960)),
            );
            expect(dto.title, 'Edited');
            expect(dto.dateStart, DateTime.utc(1960));
          }
        },
      );

      // BR 71
      test(
        'when owner or co_owner edits a published story then it changes; '
        'a draft they did not write is FORBIDDEN',
        () async {
          final published = await c.published();
          final draft = await c.draft();
          for (final steward in [c.owner, c.coOwner]) {
            final dto = await endpoints.story.updateDraft(
              by(steward),
              published.id!,
              write(body: 'by $steward'),
            );
            expect(dto.body, 'by $steward');
            await expectLater(
              endpoints.story.updateDraft(
                by(steward),
                draft.id!,
                write(body: 'x'),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 71, BR 73
      test(
        'when a plain member, a stranger, or anyone on a missing story edits '
        'then FORBIDDEN',
        () async {
          final published = await c.published();
          for (final user in [c.member, c.stranger]) {
            await expectLater(
              endpoints.story.updateDraft(
                by(user),
                published.id!,
                write(title: 'x'),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
          await expectLater(
            endpoints.story.updateDraft(by(c.author), newId(), write()),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(
            (await Story.db.findById(fx.s, published.id!))!.title,
            'A story',
          );
        },
      );

      // BR 71
      test(
        'when a child-family owner edits the parent origin story then FORBIDDEN',
        () async {
          final origin = await c.published();
          final branch = await c.branch(origin: origin);
          await expectLater(
            endpoints.story.updateDraft(
              by(branch.owner),
              origin.id!,
              write(title: 'x'),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      // BR 71
      test(
        'when the family is soft-deleted then nobody can edit, not even the author',
        () async {
          final published = await c.published();
          await fx.softDelete(c.family);
          for (final user in [c.author, c.owner]) {
            await expectLater(
              endpoints.story.updateDraft(
                by(user),
                published.id!,
                write(title: 'x'),
              ),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 72, BR 73
      test(
        'when an owner edits a published story then author, family, status, '
        'publishedAt and createdAt are unchanged',
        () async {
          final published = await c.published();
          await endpoints.story.updateDraft(
            by(c.owner),
            published.id!,
            write(title: 'Owner edit'),
          );
          final row = (await Story.db.findById(fx.s, published.id!))!;
          expect(row.title, 'Owner edit');
          expect(row.authorId, c.author);
          expect(row.familyId, c.family.id);
          expect(row.status, StoryStatus.published);
          expect(row.publishedAt, published.publishedAt);
          expect(row.createdAt, published.createdAt);
        },
      );

      test(
        'when autosaving then a draft changes and true is returned; a '
        'published story returns false and is unchanged',
        () async {
          final draft = await c.draft();
          expect(
            await endpoints.story.autosaveDraft(
              by(c.author),
              draft.id!,
              write(title: 'Saved'),
            ),
            isTrue,
          );
          expect((await Story.db.findById(fx.s, draft.id!))!.title, 'Saved');
          final published = await c.published();
          expect(
            await endpoints.story.autosaveDraft(
              by(c.author),
              published.id!,
              write(title: 'Nope'),
            ),
            isFalse,
          );
          expect(
            (await Story.db.findById(fx.s, published.id!))!.title,
            'A story',
          );
        },
      );

      test('when a non-author member autosaves then FORBIDDEN', () async {
        final draft = await c.draft();
        await expectLater(
          endpoints.story.autosaveDraft(by(c.member), draft.id!, write()),
          throwsAppError(AppErrorCode.forbidden),
        );
      });
    });

    group('tags', () {
      // BR 75
      test(
        'when an editor replaces tags then the story has exactly the new '
        'people; an empty list removes them all; null leaves them',
        () async {
          final a = await fx.person(c.family, name: 'A');
          final b = await fx.person(c.family, name: 'B');
          final story = await c.published();
          await fx.tag(story, a);
          var dto = await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(personIds: [b.id!]),
          );
          expect(dto.people.map((p) => p.personId), [b.id]);
          dto = await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(title: 'Kept tags'),
          );
          expect(dto.people.map((p) => p.personId), [b.id]);
          dto = await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(personIds: []),
          );
          expect(dto.people, isEmpty);
        },
      );

      // BR 75
      test(
        'when tagging a person homed in a child timeline of the same tree '
        'then it succeeds',
        () async {
          final branch = await c.branch();
          final childPerson = await fx.person(branch.family, name: 'Kid');
          final story = await c.draft();
          await endpoints.story.linkPerson(
            by(c.author),
            story.id!,
            childPerson.id!,
          );
          final dto = await endpoints.story.get(by(c.author), story.id!);
          expect(dto.people.map((p) => p.personId), [childPerson.id]);
        },
      );

      test(
        'when linking the same person twice then there is one tag',
        () async {
          final person = await fx.person(c.family);
          final story = await c.draft();
          await endpoints.story.linkPerson(by(c.author), story.id!, person.id!);
          await endpoints.story.linkPerson(by(c.author), story.id!, person.id!);
          expect(
            await StoryPerson.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            1,
          );
        },
      );

      // BR 76
      test(
        'when a member of two unrelated trees tags a person or uses a place '
        'from the other tree then FORBIDDEN',
        () async {
          final other = await Clan.of(fx);
          await fx.join(other.family, c.author);
          final foreigner = await fx.person(other.family);
          final foreignPlace = await fx.place(other.tree);
          final story = await c.draft();
          await expectLater(
            endpoints.story.linkPerson(by(c.author), story.id!, foreigner.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.updateDraft(
              by(c.author),
              story.id!,
              write(personIds: [foreigner.id!]),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.updateDraft(
              by(c.author),
              story.id!,
              write(placeId: foreignPlace.id),
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(
            await StoryPerson.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            0,
          );
        },
      );

      // BR 77
      test(
        'when tagging a person with a matching email or the owner then no '
        'membership is created or changed',
        () async {
          final email = 'tag-${newId()}@example.com';
          final invitee = await fx.userWithEmail(email);
          final emailed = await fx.person(c.family, name: 'Emailed');
          await Person.db.updateRow(fx.s, emailed.copyWith(email: email));
          final ownerPerson = await fx.person(c.family, userId: c.owner);
          final story = await c.draft();
          await endpoints.story.updateDraft(
            by(c.author),
            story.id!,
            write(personIds: [emailed.id!, ownerPerson.id!]),
          );
          expect(
            await Membership.db.count(
              fx.s,
              where: (t) => t.userId.equals(invitee),
            ),
            0,
          );
          final ownerRows = await Membership.db.find(
            fx.s,
            where: (t) => t.userId.equals(c.owner),
          );
          expect(ownerRows.map((m) => m.role), [MembershipRole.owner]);
        },
      );

      test(
        'when a plain member links a person to another member\'s story then '
        'FORBIDDEN',
        () async {
          final person = await fx.person(c.family);
          final story = await c.published();
          await expectLater(
            endpoints.story.linkPerson(by(c.member), story.id!, person.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );
    });

    group('live events on edits', () {
      test(
        'when a draft is created, updated, autosaved or tagged then nothing '
        'is posted',
        () async {
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(dateStart: DateTime.utc(1950)),
            allowUndated: false,
          );
          await endpoints.story.updateDraft(
            by(c.author),
            draft.id,
            write(title: 'x'),
          );
          await endpoints.story.autosaveDraft(
            by(c.author),
            draft.id,
            write(title: 'y'),
          );
          final person = await fx.person(c.family);
          await endpoints.story.linkPerson(by(c.author), draft.id, person.id!);
          await settle();
          expect(family, isEmpty);
        },
      );

      test(
        'when a published story is updated or tagged then a story event is '
        'posted on the family and story channels',
        () async {
          final story = await c.published();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final onStory = liveEvents(fx.s, storyChannel(story.id!));
          await endpoints.story.updateDraft(
            by(c.owner),
            story.id!,
            write(title: 'x'),
          );
          final person = await fx.person(c.family);
          await endpoints.story.linkPerson(by(c.author), story.id!, person.id!);
          await settle();
          expect(family, hasLength(2));
          expect(onStory, hasLength(2));
          final event = family.first;
          expect(event.familyId, c.family.id);
          expect(event.storyId, story.id);
          expect(event.kind, LiveKind.story);
          expect(event.storyStatus, StoryStatus.published);
          expect(event.deleted, isFalse);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: FAIL to load: `endpoints.story` isn't defined.

- [ ] **Step 3: Write the implementation**

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: create -->
```dart
import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../live/live_events.dart';
import '../stories/story_dates.dart';
import '../stories/story_dtos.dart';

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
    );
  }
}

// ── helpers

/// Trimmed; blank → null, so a saved title or body can be cleared.
String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
```

- [ ] **Step 4: Generate and run the tests**

Run: `mise exec -- just server-generate && cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: PASS (28 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/story_endpoint.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client apps/server/test/integration/story_endpoint_test.dart
git commit -m "feat(server): StoryEndpoint drafting, editing and tags"
```

---

### Task 4: Publish and story reads

`publish`, `getPublished`, `listMyDrafts`, `listPublished`, `listLatestPublished`, `listForPerson`. Covers BR 26 (story part), 28 (story part), 63, 67, 68 (story part), 70, 72 (publish lock), 74 (stories).

**Files:**
- Modify: `apps/server/lib/src/endpoints/story_endpoint.dart`
- Test: `apps/server/test/integration/story_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

<!-- file: apps/server/test/integration/story_endpoint_test.dart mode: tests -->
```dart
    group('publish', () {
      // BR 63
      test(
        'when a dateless draft is published then VALIDATION "date required"; '
        'with dates set it publishes',
        () async {
          final ready = await c.ready();
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            write(
              title: ready.title,
              body: ready.body,
              placeId: ready.placeId,
              personIds: ready.personIds,
            ),
            allowUndated: true,
          );
          await expectLater(
            endpoints.story.publish(by(c.author), draft.id),
            throwsAppError(AppErrorCode.validation, 'date required'),
          );
          await endpoints.story.updateDraft(
            by(c.author),
            draft.id,
            write(
              dateStart: DateTime.utc(1950),
              datePrecision: DatePrecision.year,
            ),
          );
          final dto = await endpoints.story.publish(by(c.author), draft.id);
          expect(dto.status, StoryStatus.published);
          expect(dto.publishedAt, isNotNull);
        },
      );

      test(
        'when a draft misses a title, body, person or place then VALIDATION '
        'names what is missing',
        () async {
          final ready = await c.ready();
          final cases = {
            'title required': write(title: ' '),
            'body required': write(body: ''),
            'person required': write(personIds: []),
            'place required': write(clearPlace: true),
          };
          for (final MapEntry(key: message, value: gap) in cases.entries) {
            final draft = await endpoints.story.createDraft(
              by(c.author),
              c.family.id!,
              ready,
              allowUndated: false,
            );
            await endpoints.story.updateDraft(by(c.author), draft.id, gap);
            await expectLater(
              endpoints.story.publish(by(c.author), draft.id),
              throwsAppError(AppErrorCode.validation, message),
            );
          }
        },
      );

      // BR 72
      test(
        'when an owner publishes the author\'s story then FORBIDDEN "field is '
        'locked"; the owner cannot publish a draft they cannot see',
        () async {
          final published = await c.published();
          await expectLater(
            endpoints.story.publish(by(c.owner), published.id!),
            throwsAppError(AppErrorCode.forbidden, 'field is locked'),
          );
          final draft = await c.draft();
          await expectLater(
            endpoints.story.publish(by(c.owner), draft.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(
            (await Story.db.findById(fx.s, draft.id!))!.status,
            StoryStatus.draft,
          );
        },
      );

      test(
        'when the story is published then one story event with status '
        'published is posted; publishing again posts nothing',
        () async {
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            await c.ready(),
            allowUndated: false,
          );
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final first = await endpoints.story.publish(by(c.author), draft.id);
          final again = await endpoints.story.publish(by(c.author), draft.id);
          await settle();
          expect(again.publishedAt, first.publishedAt);
          expect(family, hasLength(1));
          expect(family.single.kind, LiveKind.story);
          expect(family.single.storyId, draft.id);
          expect(family.single.storyStatus, StoryStatus.published);
        },
      );
    });

    group('reading', () {
      // BR 68 (story part)
      test(
        'when a draft exists then only its author reads it; members, '
        'stewards and tree readers do not',
        () async {
          final draft = await c.draft();
          final branch = await c.branch();
          expect(
            (await endpoints.story.get(by(c.author), draft.id!)).id,
            draft.id,
          );
          for (final user in [c.member, c.owner, c.coOwner, branch.member]) {
            await expectLater(
              endpoints.story.get(by(user), draft.id!),
              throwsAppError(AppErrorCode.notFound, 'story'),
            );
          }
          expect(
            await endpoints.story.getPublished(by(c.author), draft.id!),
            isNull,
          );
          expect(
            (await endpoints.story.listMyDrafts(
              by(c.author),
              c.family.id!,
            )).map((s) => s.id),
            [draft.id],
          );
          expect(
            await endpoints.story.listMyDrafts(by(c.owner), c.family.id!),
            isEmpty,
          );
          expect(
            await endpoints.story.listPublished(by(c.author), c.family.id!),
            isEmpty,
          );
        },
      );

      // BR 70
      test(
        'when the author publishes then members, stewards and tree readers '
        'read the story with its tags and place',
        () async {
          final draft = await endpoints.story.createDraft(
            by(c.author),
            c.family.id!,
            await c.ready(),
            allowUndated: false,
          );
          await endpoints.story.publish(by(c.author), draft.id);
          final branch = await c.branch();
          for (final user in [c.member, c.owner, c.coOwner, branch.member]) {
            final dto = await endpoints.story.get(by(user), draft.id);
            expect(dto.people, hasLength(1));
            expect(dto.placeLabel, 'Home');
            expect(
              await endpoints.story.getPublished(by(user), draft.id),
              isNotNull,
            );
            expect(
              (await endpoints.story.listPublished(
                by(user),
                c.family.id!,
              )).map((s) => s.id),
              [draft.id],
            );
          }
        },
      );

      // BR 26 (story part)
      test(
        'when a parent member reads a child family then they see its '
        'published story with tags and place, not its drafts',
        () async {
          final branch = await c.branch();
          final kid = await fx.person(branch.family, name: 'Kid');
          final place = await fx.place(c.tree);
          final story = await fx.story(
            branch.family,
            authorId: branch.member,
            placeId: place.id,
          );
          await fx.tag(story, kid);
          final draft = await fx.story(
            branch.family,
            authorId: branch.member,
            status: StoryStatus.draft,
          );
          final list = await endpoints.story.listPublished(
            by(c.member),
            branch.family.id!,
          );
          expect(list.map((s) => s.id), [story.id]);
          expect(list.single.people.map((p) => p.name), ['Kid']);
          expect(list.single.placeLabel, 'Home');
          await expectLater(
            endpoints.story.get(by(c.member), draft.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
        },
      );

      // BR 28 (story part)
      test(
        'when a stranger reads a child published story then it is refused',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          await expectLater(
            endpoints.story.get(by(c.stranger), story.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          expect(
            await endpoints.story.getPublished(by(c.stranger), story.id!),
            isNull,
          );
          await expectLater(
            endpoints.story.listPublished(by(c.stranger), branch.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      // BR 74 (stories)
      test(
        'when a member of family A reads family B then they see none of B\'s '
        'stories',
        () async {
          final b = await Clan.of(fx);
          final story = await b.published();
          await expectLater(
            endpoints.story.get(by(c.member), story.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          await expectLater(
            endpoints.story.listPublished(by(c.member), b.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.listLatestPublished(
              by(c.member),
              b.family.id!,
              withinDays: 7,
              limit: 3,
            ),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.story.listMyDrafts(by(c.member), b.family.id!),
            throwsAppError(AppErrorCode.forbidden, 'member only'),
          );
        },
      );

      // BR 67
      test(
        'when stories share a start then they are ordered year, month, day, '
        'then createdAt',
        () async {
          Future<Story> at(DatePrecision precision, DateTime end, int minute) =>
              Story.db.insertRow(
                fx.s,
                Story(
                  familyId: c.family.id!,
                  treeId: c.tree.id!,
                  authorId: c.author,
                  status: StoryStatus.published,
                  dateStart: DateTime.utc(1950),
                  dateEnd: end,
                  datePrecision: precision,
                  publishedAt: DateTime.now().toUtc(),
                  createdAt: DateTime.utc(2026, 1, 1, 0, minute),
                ),
              );
          final day = await at(DatePrecision.day, DateTime.utc(1950), 1);
          final month = await at(
            DatePrecision.month,
            DateTime.utc(1950, 1, 31),
            2,
          );
          final yearLater = await at(
            DatePrecision.year,
            DateTime.utc(1950, 12, 31),
            4,
          );
          final year = await at(
            DatePrecision.year,
            DateTime.utc(1950, 12, 31),
            3,
          );
          final list = await endpoints.story.listPublished(
            by(c.member),
            c.family.id!,
          );
          expect(list.map((s) => s.id), [
            year.id,
            yearLater.id,
            month.id,
            day.id,
          ]);
        },
      );

      test(
        'when listing the latest then published stories inside the window '
        'come newest first, at most limit',
        () async {
          Future<Story> publishedDaysAgo(int days) async {
            final story = await c.published();
            return Story.db.updateRow(
              fx.s,
              story.copyWith(
                publishedAt: DateTime.now().toUtc().subtract(
                  Duration(days: days, minutes: 1),
                ),
              ),
            );
          }

          final one = await publishedDaysAgo(1);
          final two = await publishedDaysAgo(2);
          final three = await publishedDaysAgo(3);
          await publishedDaysAgo(10);
          await c.draft();
          expect(
            (await endpoints.story.listLatestPublished(
              by(c.member),
              c.family.id!,
              withinDays: 7,
              limit: 3,
            )).map((s) => s.id),
            [one.id, two.id, three.id],
          );
          expect(
            (await endpoints.story.listLatestPublished(
              by(c.member),
              c.family.id!,
              withinDays: 30,
              limit: 2,
            )).map((s) => s.id),
            [one.id, two.id],
          );
        },
      );

      test(
        'when listing a person\'s stories then published stories tagging '
        'them across the tree come oldest first',
        () async {
          final person = await fx.person(c.family);
          final branch = await c.branch();
          final gone = await c.branch();
          final s1950 = await c.published();
          final s1940 = await Story.db.insertRow(
            fx.s,
            Story(
              familyId: branch.family.id!,
              treeId: c.tree.id!,
              authorId: branch.member,
              status: StoryStatus.published,
              dateStart: DateTime.utc(1940),
              dateEnd: DateTime.utc(1940, 12, 31),
              datePrecision: DatePrecision.year,
              publishedAt: DateTime.now().toUtc(),
            ),
          );
          final draft = await c.draft();
          final hidden = await fx.story(gone.family, authorId: gone.member);
          await fx.softDelete(gone.family);
          await c.published();
          for (final story in [s1950, s1940, draft, hidden]) {
            await fx.tag(story, person);
          }
          expect(
            (await endpoints.story.listForPerson(
              by(c.member),
              person.id!,
            )).map((s) => s.id),
            [s1940.id, s1950.id],
          );
          await expectLater(
            endpoints.story.listForPerson(by(c.stranger), person.id!),
            throwsAppError(AppErrorCode.notFound, 'person'),
          );
        },
      );

      test('when the story is missing then getPublished is null', () async {
        expect(
          await endpoints.story.getPublished(by(c.member), newId()),
          isNull,
        );
      });

      // D6b
      test(
        'when the story\'s family is soft-deleted then its former members '
        'read nothing: stories, drafts, search, facets and notes',
        () async {
          final published = await c.published();
          final draft = await c.draft();
          await fx.note(published, c.member);
          await fx.softDelete(c.family);
          for (final user in [c.author, c.member, c.owner]) {
            for (final story in [published, draft]) {
              await expectLater(
                endpoints.story.get(by(user), story.id!),
                throwsAppError(AppErrorCode.notFound, 'story'),
              );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: FAIL to load: `publish`, `getPublished`, `listMyDrafts`, `listPublished`, `listLatestPublished`, `listForPerson` aren't defined on the endpoint.

- [ ] **Step 3: Write the implementation**

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: class -->
```dart
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
```

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: top -->
```dart

/// `timelineOrder` (schema-design §0.5): dateStart, datePrecision,
/// createdAt, id ascending. Undated drafts sort last (Postgres ASC puts
/// NULLs last).
List<Order> _timelineOrder(StoryTable t) => [
  t.dateStart.asc(),
  t.datePrecision.asc(),
  t.createdAt.asc(),
  t.id.asc(),
];

/// The app's publish readiness (`publishReadiness`, stories_api.dart:314),
/// now on the server. The date comes first: it is the business-rules §4.4
/// rule.
void _requireReady(Story story, int tagCount) {
  if (story.dateStart == null) throw validation('date required');
  if ((story.title ?? '').trim().isEmpty) throw validation('title required');
  if ((story.body ?? '').trim().isEmpty) throw validation('body required');
  if (tagCount == 0) throw validation('person required');
  if (story.placeId == null) throw validation('place required');
}
```

- [ ] **Step 4: Generate and run the tests**

Run: `mise exec -- just server-generate && cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: PASS (42 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/story_endpoint.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client apps/server/test/integration/story_endpoint_test.dart
git commit -m "feat(server): StoryEndpoint publish and story reads"
```

---

### Task 5: Discard

Covers the discard path (photo keys queued, D4: owners can't delete others' stories) and BR 137 (story part).

**Files:**
- Modify: `apps/server/lib/src/endpoints/story_endpoint.dart`
- Test: `apps/server/test/integration/story_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

<!-- file: apps/server/test/integration/story_endpoint_test.dart mode: tests -->
```dart
    group('discard', () {
      test(
        'when the author discards a story then it, its photos, notes and tags '
        'are gone and both photo keys are queued',
        () async {
          final story = await c.draft();
          final plain = await fx.photo(story);
          final edited = await fx.photo(
            story,
            sortOrder: 1,
            editedKey: 'families/x/edited-1.jpg',
          );
          await fx.note(story, c.author);
          await fx.tag(story, await fx.person(c.family));
          await endpoints.story.discard(by(c.author), story.id!);
          expect(await Story.db.findById(fx.s, story.id!), isNull);
          expect(
            await Photo.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            0,
          );
          expect(
            await StoryNote.db.count(
              fx.s,
              where: (t) => t.storyId.equals(story.id!),
            ),
            0,
          );
          final queued = await BlobDeletion.db.find(
            fx.s,
            where: (t) => t.key.inSet({
              plain.originalKey,
              edited.originalKey,
              edited.editedKey!,
            }),
          );
          expect(queued, hasLength(3));
        },
      );

      // D4
      test(
        'when an owner discards another member\'s story then FORBIDDEN and it '
        'remains',
        () async {
          final story = await c.published();
          for (final user in [c.owner, c.coOwner, c.member]) {
            await expectLater(
              endpoints.story.discard(by(user), story.id!),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
          expect(await Story.db.findById(fx.s, story.id!), isNotNull);
        },
      );

      // BR 137 (story part)
      test(
        'when its author discards a story in a soft-deleted family then '
        'FORBIDDEN and nothing changes',
        () async {
          final story = await c.published();
          final photo = await fx.photo(story);
          await fx.softDelete(c.family);
          await expectLater(
            endpoints.story.discard(by(c.author), story.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(await Story.db.findById(fx.s, story.id!), isNotNull);
          expect(
            await BlobDeletion.db.count(
              fx.s,
              where: (t) => t.key.equals(photo.originalKey),
            ),
            0,
          );
        },
      );

      test(
        'when a published story is discarded then a deleted story event is '
        'posted; discarding a draft posts nothing',
        () async {
          final published = await c.published();
          final draft = await c.draft();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          await endpoints.story.discard(by(c.author), draft.id!);
          await endpoints.story.discard(by(c.author), published.id!);
          await settle();
          expect(family, hasLength(1));
          expect(family.single.storyId, published.id);
          expect(family.single.kind, LiveKind.story);
          expect(family.single.deleted, isTrue);
        },
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: FAIL to load: `discard` isn't defined.

- [ ] **Step 3: Write the implementation**

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: import -->
```dart
import '../media/blob_outbox.dart';
```

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: class -->
```dart
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
```

- [ ] **Step 4: Generate and run the tests**

Run: `mise exec -- just server-generate && cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: PASS (46 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/story_endpoint.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client apps/server/test/integration/story_endpoint_test.dart
git commit -m "feat(server): StoryEndpoint discard queues photo blobs"
```

---

### Task 6: Search and facets

Endpoint-contract §2.2 search semantics: scope, AND people, exact place, decades over range, escaped ILIKE text over title/body/place/people/year/decade label, relevance tiers and the three sorts; facets over the same scope.

**Files:**
- Create: `apps/server/lib/src/stories/story_search.dart`
- Modify: `apps/server/lib/src/endpoints/story_endpoint.dart`
- Test: `apps/server/test/integration/story_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

<!-- file: apps/server/test/integration/story_endpoint_test.dart mode: tests -->
```dart
    group('search', () {
      StorySearchDto query(
        UuidValue familyId, {
        String text = '',
        List<UuidValue> personIds = const [],
        UuidValue? placeId,
        DateTime? rangeStart,
        DateTime? rangeEnd,
        List<int> decades = const [],
        SearchSort sort = SearchSort.relevant,
      }) => StorySearchDto(
        familyId: familyId,
        text: text,
        personIds: personIds,
        placeId: placeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        decades: decades,
        sort: sort,
      );

      Future<Story> dated(
        int year, {
        String? title,
        String? body,
        UuidValue? placeId,
        DateTime? publishedAt,
        StoryStatus status = StoryStatus.published,
      }) => Story.db.insertRow(
        fx.s,
        Story(
          familyId: c.family.id!,
          treeId: c.tree.id!,
          authorId: c.author,
          title: title,
          body: body,
          status: status,
          dateStart: DateTime.utc(year),
          dateEnd: DateTime.utc(year, 12, 31),
          datePrecision: DatePrecision.year,
          placeId: placeId,
          publishedAt: status == StoryStatus.published
              ? publishedAt ?? DateTime.now().toUtc()
              : null,
        ),
      );

      Future<List<UuidValue?>> ids(StorySearchDto q, [UuidValue? user]) async =>
          (await endpoints.story.search(
            by(user ?? c.member),
            q,
          )).map((s) => s.id).toList();

      test(
        'when text matches then title ranks over person and place, which '
        'rank over body and year',
        () async {
          final harbor = await Place.db.insertRow(
            fx.s,
            Place(
              treeId: c.tree.id!,
              label: 'Harbor House',
              address: '1 Main St',
              lat: 0,
              lng: 0,
            ),
          );
          final byTitle = await dated(1950, title: 'Harbor days');
          final byPlace = await dated(1960, placeId: harbor.id);
          final byPerson = await dated(1970);
          await fx.tag(byPerson, await fx.person(c.family, name: 'Ann HARBOR'));
          final byBody = await dated(1980, body: 'by the harbor');
          await dated(1990, title: 'Nothing here');
          expect(await ids(query(c.family.id!, text: ' harbor ')), [
            byTitle.id,
            byPerson.id,
            byPlace.id,
            byBody.id,
          ]);
        },
      );

      test(
        'when text is a year or a decade label then it matches, for any decade',
        () async {
          final old = await dated(1855);
          await dated(1950);
          for (final text in ['1850s', '1855', '185']) {
            expect(await ids(query(c.family.id!, text: text)), [old.id]);
          }
        },
      );

      test('when text holds % or _ then they match literally', () async {
        final percent = await dated(1950, title: '100% true');
        await dated(1950, title: '100 true');
        expect(await ids(query(c.family.id!, text: '0%')), [percent.id]);
        expect(await ids(query(c.family.id!, text: '_')), isEmpty);
      });

      test(
        'when people, a place, decades or a range are given then they filter',
        () async {
          final a = await fx.person(c.family, name: 'A');
          final b = await fx.person(c.family, name: 'B');
          final place = await fx.place(c.tree);
          final both = await dated(1950, placeId: place.id);
          final onlyA = await dated(1962);
          await fx.tag(both, a);
          await fx.tag(both, b);
          await fx.tag(onlyA, a);
          expect(
            await ids(query(c.family.id!, personIds: [a.id!, b.id!, a.id!])),
            [both.id],
          );
          expect(
            await ids(query(c.family.id!, personIds: [a.id!])),
            [onlyA.id, both.id],
          );
          expect(await ids(query(c.family.id!, placeId: place.id)), [both.id]);
          expect(
            await ids(
              query(
                c.family.id!,
                decades: [1960],
                rangeStart: DateTime.utc(1950),
                rangeEnd: DateTime.utc(1950, 12, 31),
              ),
            ),
            [onlyA.id],
          );
          expect(
            await ids(
              query(
                c.family.id!,
                rangeStart: DateTime.utc(1950, 6),
                rangeEnd: DateTime.utc(1951),
              ),
            ),
            [both.id],
          );
          expect(
            await ids(query(c.family.id!, rangeStart: DateTime.utc(1951))),
            [onlyA.id, both.id],
          );
        },
      );

      test(
        'when sorting chronologically then the newest timeframe comes first; '
        'recentlyAdded orders by publishedAt',
        () async {
          final now = DateTime.now().toUtc();
          final old = await dated(1900, publishedAt: now);
          final mid = await dated(
            1950,
            publishedAt: now.subtract(const Duration(days: 2)),
          );
          final recent = await dated(
            2000,
            publishedAt: now.subtract(const Duration(days: 1)),
          );
          expect(
            await ids(query(c.family.id!, sort: SearchSort.chronological)),
            [recent.id, mid.id, old.id],
          );
          expect(
            await ids(query(c.family.id!, sort: SearchSort.recentlyAdded)),
            [old.id, recent.id, mid.id],
          );
        },
      );

      test(
        'when searching then drafts and other families are excluded, tree '
        'readers may search, and strangers are FORBIDDEN',
        () async {
          final story = await dated(1950, title: 'Mine');
          await dated(1951, title: 'Mine draft', status: StoryStatus.draft);
          final other = await Clan.of(fx);
          await fx.story(other.family, authorId: other.author);
          final branch = await c.branch();
          expect(await ids(query(c.family.id!, text: 'mine')), [story.id]);
          expect(
            await ids(query(c.family.id!), branch.member),
            [story.id],
          );
          await expectLater(
            endpoints.story.search(by(c.stranger), query(c.family.id!)),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );

      test(
        'when listing facets then decades ascend and people and places are '
        'counted over published stories only',
        () async {
          final branch = await c.branch();
          final zed = await fx.person(branch.family, name: 'Zed');
          final amy = await fx.person(c.family, name: 'Amy');
          final place = await fx.place(c.tree);
          final s1950 = await dated(1950, placeId: place.id);
          final s1955 = await dated(1955);
          await dated(1880);
          final draft = await dated(1990, status: StoryStatus.draft);
          await fx.tag(s1950, zed);
          await fx.tag(s1955, zed);
          await fx.tag(s1955, amy);
          await fx.tag(draft, amy);
          final facets = await endpoints.story.facets(
            by(c.member),
            c.family.id!,
          );
          expect(facets.decades.map((d) => (d.decade, d.storyCount)), [
            (1880, 1),
            (1950, 2),
          ]);
          expect(facets.people.map((p) => (p.personId, p.name, p.storyCount)), [
            (amy.id, 'Amy', 1),
            (zed.id, 'Zed', 2),
          ]);
          expect(facets.places.map((p) => (p.placeId, p.label, p.storyCount)), [
            (place.id, 'Home', 1),
          ]);
          await expectLater(
            endpoints.story.facets(by(c.stranger), c.family.id!),
            throwsAppError(AppErrorCode.forbidden),
          );
        },
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: FAIL to load: `search` and `facets` aren't defined.

- [ ] **Step 3: Write the search SQL**

<!-- file: apps/server/lib/src/stories/story_search.dart mode: create -->
```dart
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

const _year = 'extract(year FROM st."dateStart")::int';
const _decade = '(extract(year FROM st."dateStart")::int / 10 * 10)';
const _scope = 'st."familyId" = @familyId::uuid AND st.status = \'published\'';
const _newestFirst =
    '"dateStart" DESC, "datePrecision" DESC, "createdAt" DESC, s.id DESC';

/// Ids of the published stories of `q.familyId` matching [q], in result
/// order (endpoint-contract §2.2, search semantics). Authorization is the
/// caller's job.
///
/// - `personIds`: AND (every person tagged); `placeId`: exact.
/// - `decades` non-empty: `floor(year/10)*10 ∈ decades`; otherwise, when
///   both range bounds are set, overlap with `[rangeStart, rangeEnd]`.
/// - `text` (trimmed): case-insensitive substring (ILIKE, `%`/`_`/`\`
///   escaped) over title (tier 3), person names / place label / address
///   (tier 2), body / start year / `'<decade>s'` (tier 1).
/// - sorts: `relevant` = tier desc, then newest timeline first;
///   `chronological` = newest timeline first; `recentlyAdded` = publishedAt
///   desc nulls last, then newest timeline first.
Future<List<UuidValue>> searchStoryIds(
  Session session,
  StorySearchDto q,
) async {
  final params = <String, Object?>{'familyId': q.familyId.uuid};
  final where = [_scope];

  final personIds = {for (final id in q.personIds) id.uuid}.toList();
  if (personIds.isNotEmpty) {
    params['personIds'] = personIds;
    params['personCount'] = personIds.length;
    where.add(
      '(SELECT count(*) FROM story_people sp WHERE sp."storyId" = st.id '
      'AND sp."personId" = ANY(@personIds::uuid[])) = @personCount',
    );
  }
  final placeId = q.placeId;
  if (placeId != null) {
    params['placeId'] = placeId.uuid;
    where.add('st."placeId" = @placeId::uuid');
  }
  final rangeStart = q.rangeStart;
  final rangeEnd = q.rangeEnd;
  if (q.decades.isNotEmpty) {
    params['decades'] = q.decades.toSet().toList();
    where.add('$_decade = ANY(@decades::int[])');
  } else if (rangeStart != null && rangeEnd != null) {
    params['rangeStart'] = rangeStart;
    params['rangeEnd'] = rangeEnd;
    where.add('st."dateStart" <= @rangeEnd AND @rangeStart <= st."dateEnd"');
  }

  final text = q.text.trim();
  var tier = '0';
  if (text.isNotEmpty) {
    params['pattern'] = '%${_escapeLike(text)}%';
    tier =
        'CASE '
        'WHEN st.title ILIKE @pattern THEN 3 '
        'WHEN pl.label ILIKE @pattern OR pl.address ILIKE @pattern '
        'OR EXISTS (SELECT 1 FROM story_people sp '
        'JOIN people p ON p.id = sp."personId" '
        'WHERE sp."storyId" = st.id AND p.name ILIKE @pattern) THEN 2 '
        'WHEN st.body ILIKE @pattern OR $_year::text ILIKE @pattern '
        "OR ($_decade::text || 's') ILIKE @pattern THEN 1 "
        'ELSE 0 END';
  }
  final order = switch (q.sort) {
    SearchSort.relevant => 'tier DESC, $_newestFirst',
    SearchSort.chronological => _newestFirst,
    SearchSort.recentlyAdded => '"publishedAt" DESC NULLS LAST, $_newestFirst',
  };
  final rows = await session.db.unsafeQuery(
    'SELECT s.id::text FROM ('
    'SELECT st.id, st."dateStart", st."datePrecision", st."createdAt", '
    'st."publishedAt", $tier AS tier '
    'FROM stories st LEFT JOIN places pl ON pl.id = st."placeId" '
    'WHERE ${where.join(' AND ')}'
    ') s ${text.isEmpty ? '' : 'WHERE tier > 0 '}'
    'ORDER BY $order',
    parameters: QueryParameters.named(params),
  );
  return [for (final row in rows) UuidValue.fromString(row[0] as String)];
}

/// Facets over the same scope as [searchStoryIds] without filters: decades
/// ascending, tagged people (any home family) by name, places by label.
Future<StoryFacetsDto> storyFacets(Session session, UuidValue familyId) async {
  final params = QueryParameters.named({'familyId': familyId.uuid});
  final decades = await session.db.unsafeQuery(
    'SELECT $_decade, count(*)::int FROM stories st WHERE $_scope '
    'GROUP BY 1 ORDER BY 1',
    parameters: params,
  );
  final people = await session.db.unsafeQuery(
    'SELECT p.id::text, p.name, count(*)::int FROM stories st '
    'JOIN story_people sp ON sp."storyId" = st.id '
    'JOIN people p ON p.id = sp."personId" '
    'WHERE $_scope GROUP BY p.id, p.name ORDER BY p.name, p.id',
    parameters: params,
  );
  final places = await session.db.unsafeQuery(
    'SELECT pl.id::text, pl.label, count(*)::int FROM stories st '
    'JOIN places pl ON pl.id = st."placeId" '
    'WHERE $_scope GROUP BY pl.id, pl.label ORDER BY pl.label, pl.id',
    parameters: params,
  );
  return StoryFacetsDto(
    decades: [
      for (final row in decades)
        DecadeFacetDto(decade: row[0] as int, storyCount: row[1] as int),
    ],
    people: [
      for (final row in people)
        PersonFacetDto(
          personId: UuidValue.fromString(row[0] as String),
          name: row[1] as String,
          storyCount: row[2] as int,
        ),
    ],
    places: [
      for (final row in places)
        PlaceFacetDto(
          placeId: UuidValue.fromString(row[0] as String),
          label: row[1] as String,
          storyCount: row[2] as int,
        ),
    ],
  );
}

/// [text] with LIKE wildcards and the escape character escaped.
String _escapeLike(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
```

- [ ] **Step 4: Add the endpoint methods**

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: import -->
```dart
import '../stories/story_search.dart';
```

<!-- file: apps/server/lib/src/endpoints/story_endpoint.dart mode: class -->
```dart
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
```

- [ ] **Step 5: Generate and run the tests**

Run: `mise exec -- just server-generate && cd apps/server && mise exec -- dart test test/integration/story_endpoint_test.dart`
Expected: PASS (53 tests).

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/stories/story_search.dart apps/server/lib/src/endpoints/story_endpoint.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client apps/server/test/integration/story_endpoint_test.dart
git commit -m "feat(server): story search and facets"
```

---

### Task 7: NoteEndpoint

`listForStory`, `create`, `update`, `delete`, with `NoteDto.canDelete` (D4). Covers BR 26–28 (comment/perspective part), 43–45, 68 and 69 (comment/perspective part), 74 (notes), 83 (comment/perspective part), 93, 94, and the note live events.

**Files:**
- Create: `apps/server/lib/src/endpoints/note_endpoint.dart`
- Test: `apps/server/test/integration/note_endpoint_test.dart`
- Generated: as in Task 3

- [ ] **Step 1: Write the failing test**

<!-- file: apps/server/test/integration/note_endpoint_test.dart mode: create -->
```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/stories_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given NoteEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late Clan c;
    TestSessionBuilder by(UuidValue user) => asUser(sessionBuilder, user);

    setUp(() async {
      fx = Fx(sessionBuilder.build());
      c = await Clan.of(fx);
    });

    Future<NoteDto> comment(
      UuidValue user,
      Story story, {
      NoteKind kind = NoteKind.comment,
      String body = 'Hello',
    }) => endpoints.note.create(by(user), story.id!, kind, body);

    test('when an anonymous caller lists notes then it is refused', () async {
      final story = await c.published();
      await expectLater(
        endpoints.note.listForStory(sessionBuilder, story.id!),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });

    group('own notes and moderation', () {
      // BR 93
      test(
        'when member B creates, edits and deletes their own comment and '
        'perspective then each succeeds',
        () async {
          final story = await c.published();
          for (final kind in NoteKind.values) {
            final note = await comment(
              c.member,
              story,
              kind: kind,
              body: ' Hi ',
            );
            expect(note.body, 'Hi');
            expect(note.kind, kind);
            expect(note.authorId, c.member);
            expect(note.familyId, c.family.id);
            expect(note.canDelete, isTrue);
            await endpoints.note.update(by(c.member), note.id, 'Edited');
            final listed = await endpoints.note.listForStory(
              by(c.member),
              story.id!,
              kind: kind,
            );
            expect(listed.single.body, 'Edited');
            await endpoints.note.delete(by(c.member), note.id);
            expect(
              await endpoints.note.listForStory(by(c.member), story.id!),
              isEmpty,
            );
          }
        },
      );

      // BR 93
      test(
        'when member A edits or deletes B\'s note then FORBIDDEN, and A sees '
        'canDelete false',
        () async {
          final story = await c.published();
          final note = await comment(c.member, story);
          await expectLater(
            endpoints.note.update(by(c.author), note.id, 'x'),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.delete(by(c.author), note.id),
            throwsAppError(AppErrorCode.forbidden),
          );
          final listed = await endpoints.note.listForStory(
            by(c.author),
            story.id!,
          );
          expect(listed.single.body, 'Hello');
          expect(listed.single.canDelete, isFalse);
        },
      );

      // BR 93, D4
      test(
        'when owner or co_owner deletes B\'s note on a published story then '
        'it is deleted; editing it is FORBIDDEN',
        () async {
          final story = await c.published();
          for (final steward in [c.owner, c.coOwner]) {
            final note = await comment(c.member, story);
            final listed = await endpoints.note.listForStory(
              by(steward),
              story.id!,
            );
            expect(listed.single.canDelete, isTrue);
            await expectLater(
              endpoints.note.update(by(steward), note.id, 'x'),
              throwsAppError(AppErrorCode.forbidden),
            );
            await endpoints.note.delete(by(steward), note.id);
            expect(await StoryNote.db.findById(fx.s, note.id), isNull);
          }
        },
      );

      // BR 93, D4
      test(
        'when a child-family owner deletes a note on the parent origin story '
        'then FORBIDDEN',
        () async {
          final origin = await c.published();
          final branch = await c.branch(origin: origin);
          final note = await comment(c.member, origin);
          final listed = await endpoints.note.listForStory(
            by(branch.owner),
            origin.id!,
          );
          expect(listed.single.canDelete, isFalse);
          await expectLater(
            endpoints.note.delete(by(branch.owner), note.id),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect(await StoryNote.db.findById(fx.s, note.id), isNotNull);
        },
      );

      // BR 93
      test('when a stranger comments then FORBIDDEN', () async {
        final story = await c.published();
        await expectLater(
          comment(c.stranger, story),
          throwsAppError(AppErrorCode.forbidden),
        );
      });

      // BR 94
      test(
        'when a note is edited then only its body changes',
        () async {
          final story = await c.published();
          final note = await fx.note(
            story,
            c.member,
            kind: NoteKind.perspective,
          );
          await endpoints.note.update(by(c.member), note.id!, 'New body');
          final row = (await StoryNote.db.findById(fx.s, note.id!))!;
          expect(row.body, 'New body');
          expect(row.storyId, note.storyId);
          expect(row.authorId, note.authorId);
          expect(row.kind, note.kind);
          expect(row.createdAt, note.createdAt);
        },
      );

      test(
        'when the body is blank then VALIDATION "body is required"',
        () async {
          final story = await c.published();
          await expectLater(
            comment(c.member, story, body: '  '),
            throwsAppError(AppErrorCode.validation, 'body is required'),
          );
          final note = await comment(c.member, story);
          await expectLater(
            endpoints.note.update(by(c.member), note.id, ''),
            throwsAppError(AppErrorCode.validation, 'body is required'),
          );
        },
      );

      test(
        'when listing by kind then only that kind comes back, oldest first',
        () async {
          final story = await c.published();
          final first = await comment(c.member, story, body: 'one');
          await comment(c.member, story, kind: NoteKind.perspective);
          final second = await comment(c.author, story, body: 'two');
          final comments = await endpoints.note.listForStory(
            by(c.member),
            story.id!,
            kind: NoteKind.comment,
          );
          expect(comments.map((n) => n.id), [first.id, second.id]);
          expect(
            await endpoints.note.listForStory(by(c.member), story.id!),
            hasLength(3),
          );
        },
      );
    });

    group('origin contributors', () {
      // BR 43
      test(
        'when a child member comments or adds a perspective on the origin '
        'story then allowed; on another parent story FORBIDDEN',
        () async {
          final origin = await c.published();
          final other = await c.published();
          final branch = await c.branch(origin: origin);
          for (final kind in NoteKind.values) {
            final note = await comment(branch.member, origin, kind: kind);
            expect(note.canDelete, isTrue);
            await expectLater(
              comment(branch.member, other, kind: kind),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 44
      test(
        'when a member of another branch or a stranger contributes to the '
        'origin story then FORBIDDEN',
        () async {
          final origin = await c.published();
          await c.branch(origin: origin);
          final sibling = await c.branch();
          for (final user in [sibling.member, sibling.owner, c.stranger]) {
            await expectLater(
              comment(user, origin),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 45
      test(
        'when the origin moves or is unpublished then the child member can no '
        'longer comment or edit their note',
        () async {
          final origin = await c.published();
          final elsewhere = await c.published();
          final branch = await c.branch(origin: origin);
          final note = await comment(branch.member, origin);

          await fx.origin(branch.family, elsewhere);
          await expectLater(
            comment(branch.member, origin),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.update(by(branch.member), note.id, 'x'),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.delete(by(branch.member), note.id),
            throwsAppError(AppErrorCode.forbidden),
          );

          await fx.origin(branch.family, origin);
          await fx.setStatus(origin, StoryStatus.draft);
          await expectLater(
            comment(branch.member, origin),
            throwsAppError(AppErrorCode.forbidden),
          );
          await expectLater(
            endpoints.note.update(by(branch.member), note.id, 'x'),
            throwsAppError(AppErrorCode.forbidden),
          );
          expect((await StoryNote.db.findById(fx.s, note.id))!.body, 'Hello');
        },
      );
    });

    group('tree reading', () {
      // BR 26 (comment/perspective part)
      test(
        'when a parent member reads a child published story then they see its '
        'comments and perspectives',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          await fx.note(story, branch.member);
          await fx.note(story, branch.owner, kind: NoteKind.perspective);
          final listed = await endpoints.note.listForStory(
            by(c.member),
            story.id!,
          );
          expect(listed.map((n) => n.kind).toSet(), {
            NoteKind.comment,
            NoteKind.perspective,
          });
          expect(listed.every((n) => !n.canDelete), isTrue);
        },
      );

      // BR 27 (comment/perspective part)
      test(
        'when a parent member comments on a child story then FORBIDDEN',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          for (final kind in NoteKind.values) {
            await expectLater(
              comment(c.member, story, kind: kind),
              throwsAppError(AppErrorCode.forbidden),
            );
          }
        },
      );

      // BR 28 (comment/perspective part), BR 74 (notes)
      test(
        'when a stranger or a member of an unrelated family lists notes then '
        'NOT_FOUND',
        () async {
          final branch = await c.branch();
          final story = await fx.story(branch.family, authorId: branch.member);
          await fx.note(story, branch.member);
          final b = await Clan.of(fx);
          final theirs = await b.published();
          await fx.note(theirs, b.member);
          await expectLater(
            endpoints.note.listForStory(by(c.stranger), story.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
          await expectLater(
            endpoints.note.listForStory(by(c.member), theirs.id!),
            throwsAppError(AppErrorCode.notFound, 'story'),
          );
        },
      );
    });

    group('drafts', () {
      // BR 68 (comment/perspective part)
      test(
        'when a draft has notes then only its author reads them',
        () async {
          final draft = await c.draft();
          await fx.note(draft, c.author);
          await fx.note(draft, c.author, kind: NoteKind.perspective);
          final branch = await c.branch();
          expect(
            await endpoints.note.listForStory(by(c.author), draft.id!),
            hasLength(2),
          );
          for (final user in [c.member, c.owner, c.coOwner, branch.member]) {
            await expectLater(
              endpoints.note.listForStory(by(user), draft.id!),
              throwsAppError(AppErrorCode.notFound, 'story'),
            );
          }
        },
      );

      // BR 69 (comment/perspective part)
      test(
        'when a non-author member or the owner comments on someone\'s draft '
        'then FORBIDDEN',
        () async {
          final draft = await c.draft();
          for (final user in [c.member, c.owner]) {
            for (final kind in NoteKind.values) {
              await expectLater(
                comment(user, draft, kind: kind),
                throwsAppError(AppErrorCode.forbidden),
              );
            }
          }
        },
      );

      // BR 83 (comment/perspective part)
      test(
        'when story D reverts to draft then B cannot delete their notes on it; '
        'author A deletes their own; on published P, B deletes their own',
        () async {
          final d = await c.published();
          final p = await c.published();
          final bComment = await comment(c.member, d);
          final bPerspective = await comment(
            c.member,
            d,
            kind: NoteKind.perspective,
          );
          final aComment = await comment(c.author, d);
          final onP = await comment(c.member, p);
          await fx.setStatus(d, StoryStatus.draft);
          for (final note in [bComment, bPerspective]) {
            await expectLater(
              endpoints.note.delete(by(c.member), note.id),
              throwsAppError(AppErrorCode.forbidden),
            );
            expect(await StoryNote.db.findById(fx.s, note.id), isNotNull);
          }
          await endpoints.note.delete(by(c.author), aComment.id);
          expect(await StoryNote.db.findById(fx.s, aComment.id), isNull);
          await endpoints.note.delete(by(c.member), onP.id);
          expect(await StoryNote.db.findById(fx.s, onP.id), isNull);
        },
      );

      // D4: moderation needs a published story
      test('when the owner deletes a note on a draft then FORBIDDEN', () async {
        final draft = await c.draft();
        final note = await fx.note(draft, c.author);
        await expectLater(
          endpoints.note.delete(by(c.owner), note.id!),
          throwsAppError(AppErrorCode.forbidden),
        );
      });
    });

    group('live events', () {
      test(
        'when notes on a published story are created, edited and deleted then '
        'note events are posted on the family and story channels',
        () async {
          final story = await c.published();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final onStory = liveEvents(fx.s, storyChannel(story.id!));
          final note = await comment(c.member, story);
          await endpoints.note.update(by(c.member), note.id, 'x');
          await endpoints.note.delete(by(c.member), note.id);
          await settle();
          expect(family.map((e) => (e.kind, e.storyId, e.deleted)), [
            (LiveKind.note, story.id, false),
            (LiveKind.note, story.id, false),
            (LiveKind.note, story.id, true),
          ]);
          expect(family.first.storyStatus, StoryStatus.published);
          expect(onStory, hasLength(3));
        },
      );

      test(
        'when the author comments on their draft then nothing is posted',
        () async {
          final draft = await c.draft();
          final family = liveEvents(fx.s, familyChannel(c.family.id!));
          final note = await comment(c.author, draft);
          await endpoints.note.update(by(c.author), note.id, 'x');
          await endpoints.note.delete(by(c.author), note.id);
          await settle();
          expect(family, isEmpty);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/server && mise exec -- dart test test/integration/note_endpoint_test.dart`
Expected: FAIL to load: `endpoints.note` isn't defined.

- [ ] **Step 3: Write the implementation**

<!-- file: apps/server/lib/src/endpoints/note_endpoint.dart mode: create -->
```dart
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
  );
}
```

- [ ] **Step 4: Generate and run the tests**

Run: `mise exec -- just server-generate && cd apps/server && mise exec -- dart test test/integration/note_endpoint_test.dart`
Expected: PASS (21 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/note_endpoint.dart apps/server/lib/src/generated apps/server/test/integration/test_tools packages/tell_me_a_story_client apps/server/test/integration/note_endpoint_test.dart
git commit -m "feat(server): NoteEndpoint with steward moderation (D4)"
```

---

### Task 8: Gate

- [ ] **Step 1: Format**

Run: `mise exec -- dart format apps/server/lib apps/server/test && mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test`
Expected: `Formatted N files (0 changed)` on the second command.

- [ ] **Step 2: Analyze**

Run: `cd apps/server && mise exec -- dart analyze lib test && cd ../../packages/tell_me_a_story_client && mise exec -- dart pub get && mise exec -- dart analyze`
(A fresh worktree needs the `pub get` in the client package, or analyze reports `uri_does_not_exist` for `serverpod_client`.)
Expected: `No issues found!` twice.

- [ ] **Step 3: Test**

Run: `mise exec -- just server-test`
Expected: `All tests passed!` (181 tests: 100 from 3.0, 6 unit, 1 DTO, 53 story, 21 note).

- [ ] **Step 4: Commit any formatting changes**

```bash
git add -A apps/server packages/tell_me_a_story_client
git commit -m "style(server): format Phase 3c"
```

## Port coverage

| §7 case | Test |
|---|---|
| 26 | `story_endpoint_test` reading "parent member reads a child family"; `note_endpoint_test` tree reading "parent member reads a child published story" |
| 27 | `note_endpoint_test` "parent member comments on a child story" (photo part is 3d) |
| 28 | `story_endpoint_test` "stranger reads a child published story"; `note_endpoint_test` "stranger or a member of an unrelated family lists notes"; anonymous: one test per endpoint class |
| 43, 44, 45 | `note_endpoint_test` origin contributors (photo/blob parts are 3d) |
| 62, 64, 65, 66 | `story_dates_test` and `story_endpoint_test` creating drafts |
| 63 | `story_endpoint_test` publish "dateless draft" |
| 67 | `story_endpoint_test` reading "stories share a start" |
| 68, 69 | `story_endpoint_test` reading "only its author reads it"; `note_endpoint_test` drafts (photo/blob parts are 3d) |
| 70 | `story_endpoint_test` reading "author publishes" |
| 71 | `story_endpoint_test` editing (5 tests) |
| 72 | `story_endpoint_test` publish "owner publishes the author's story" and editing "author, family, status … unchanged" |
| 73 | `story_endpoint_test` editing "plain member, a stranger …" and "unchanged" (no API moves a story) |
| 74 | `story_endpoint_test` reading "family A reads family B"; `note_endpoint_test` "member of an unrelated family" |
| 75, 76, 77 | `story_endpoint_test` tags |
| 83 | `note_endpoint_test` drafts "story D reverts to draft" |
| 93 | `note_endpoint_test` own notes and moderation |
| 94 | `note_endpoint_test` "only its body changes" |
| 137 (story part) | `story_endpoint_test` discard "soft-deleted family" |
| D6b reads | `story_endpoint_test` reading "family is soft-deleted then its former members read nothing" |

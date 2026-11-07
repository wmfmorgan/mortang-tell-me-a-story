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

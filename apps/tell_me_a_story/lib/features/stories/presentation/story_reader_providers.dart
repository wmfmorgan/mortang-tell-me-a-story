import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/comment.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/perspective.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/photo.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';

part 'story_reader_providers.g.dart';

/// What the reader shows for one story id.
sealed class ReaderLoad {
  const ReaderLoad();
}

/// No published story with this id (missing, or still a draft).
final class ReaderMissing extends ReaderLoad {
  const ReaderMissing();
}

final class ReaderReady extends ReaderLoad {
  const ReaderReady(this.data);

  final ReaderData data;
}

/// A loaded published story and everything shown around it.
@immutable
class ReaderData {
  const ReaderData({
    required this.story,
    required this.generation,
    this.authorBytes,
    this.people = const [],
    this.place,
    this.photos = const [],
    this.previews = const {},
    this.comments = const [],
    this.perspectives = const [],
    this.canWrite = false,
    this.memberOfStoryFamily = false,
    this.tree = const [],
    this.stewarded = const [],
    this.partialError = false,
  });

  final Story story;

  /// Bumped by every server load; local edits keep it.
  final int generation;
  final Uint8List? authorBytes;
  final List<Person> people;
  final Place? place;
  final List<Photo> photos;
  final Map<String, Uint8List> previews;
  final List<Comment> comments;
  final List<Perspective> perspectives;
  final bool canWrite;
  final bool memberOfStoryFamily;
  final List<TreeFamily> tree;
  final List<StewardFamily> stewarded;

  /// A side load (people, place, photos, comments, perspectives) failed.
  final bool partialError;

  ReaderData copyWith({
    List<Photo>? photos,
    Map<String, Uint8List>? previews,
    List<Comment>? comments,
    List<Perspective>? perspectives,
  }) {
    return ReaderData(
      story: story,
      generation: generation,
      authorBytes: authorBytes,
      people: people,
      place: place,
      photos: photos ?? this.photos,
      previews: previews ?? this.previews,
      comments: comments ?? this.comments,
      perspectives: perspectives ?? this.perspectives,
      canWrite: canWrite,
      memberOfStoryFamily: memberOfStoryFamily,
      tree: tree,
      stewarded: stewarded,
      partialError: partialError,
    );
  }
}

/// Failed loads stay failed until the reader reloads (no automatic retry).
Duration? _noRetry(int retryCount, Object error) => null;

/// The published story at `/stories/:storyId` with its people, place,
/// photos, notes and the caller's access. [reload] refetches in place.
@Riverpod(retry: _noRetry)
class StoryReader extends _$StoryReader {
  var _generation = 0;

  @override
  Future<ReaderLoad> build(String storyId) => _fetch();

  /// Refetches without a loading state; the old story stays until it lands.
  Future<void> reload() async {
    final next = await AsyncValue.guard(_fetch);
    if (!ref.mounted) return;
    state = next;
  }

  /// Applies a local edit (a posted comment, an uploaded photo, …).
  void edit(ReaderData Function(ReaderData data) change) {
    if (state.value case ReaderReady(:final data)) {
      state = AsyncData(ReaderReady(change(data)));
    }
  }

  Future<ReaderLoad> _fetch() async {
    final story = await ref
        .read(storiesRepositoryProvider)
        .getPublished(storyId);
    if (story == null || story.status != StoryStatus.published) {
      return const ReaderMissing();
    }
    final access = await _access(story);
    final people = await _people(story);
    final place = await _place(story);
    final photos = await _photos(story);
    final comments = await _comments(story);
    final perspectives = await _perspectives(story);
    return ReaderReady(
      ReaderData(
        story: story,
        generation: ++_generation,
        authorBytes: await _authorBytes(story),
        people: people.value,
        place: place.value,
        photos: photos.value.photos,
        previews: photos.value.previews,
        comments: comments.value,
        perspectives: perspectives.value,
        canWrite: access.canWrite,
        memberOfStoryFamily: access.member,
        tree: access.tree,
        stewarded: access.stewarded,
        partialError:
            people.failed ||
            place.failed ||
            photos.failed ||
            comments.failed ||
            perspectives.failed,
      ),
    );
  }

  /// Membership of the story family, or of a branch it starts, grants write.
  Future<_Access> _access(Story story) async {
    final families = ref.read(familiesRepositoryProvider);
    try {
      final mine = await families.listMine();
      final member = mine.any((family) => family.id == story.familyId);
      final tree = await _orEmpty(
        () => families.listFamilyTree(story.familyId),
      );
      final stewarded = await _orEmpty(families.listStewarded);
      final mineIds = {for (final family in mine) family.id};
      final canWrite =
          member ||
          tree.any(
            (row) =>
                row.parentFamilyId == story.familyId &&
                row.originStoryId == story.id &&
                mineIds.contains(row.id),
          );
      return (
        member: member,
        canWrite: canWrite,
        tree: tree,
        stewarded: stewarded,
      );
    } on AppException {
      // No membership answer: read-only, like a non-member.
      return (
        member: false,
        canWrite: false,
        tree: const <TreeFamily>[],
        stewarded: const <StewardFamily>[],
      );
    }
  }

  Future<_Loaded<List<Person>>> _people(Story story) async {
    try {
      final all = await ref
          .read(peopleRepositoryProvider)
          .listTreePeople(story.familyId);
      final onStory = [
        for (final person in all)
          if (story.personIds.contains(person.id)) person,
      ];
      return (value: onStory, failed: false);
    } catch (_) {
      // Shown as the reader's Try again SnackBar.
      return (value: const <Person>[], failed: true);
    }
  }

  Future<_Loaded<Place?>> _place(Story story) async {
    final placeId = story.placeId;
    if (placeId == null || placeId.isEmpty) return (value: null, failed: false);
    try {
      final place = await ref.read(placesRepositoryProvider).getPlace(placeId);
      return (value: place, failed: false);
    } catch (_) {
      // Shown as the reader's Try again SnackBar.
      return (value: null, failed: true);
    }
  }

  Future<_Loaded<_Photos>> _photos(Story story) async {
    final api = ref.read(photosRepositoryProvider);
    try {
      final photos = await api.listPhotos(story.id);
      final previews = <String, Uint8List>{};
      for (final photo in photos) {
        try {
          previews[photo.id] = await api.downloadBytes(
            photo.effectiveStoragePath,
          );
        } catch (_) {
          // Missing bytes fall back to the PhotoStrip placeholder icon.
          continue;
        }
      }
      return (value: (photos: photos, previews: previews), failed: false);
    } catch (_) {
      // Shown as the reader's Try again SnackBar.
      return (
        value: (photos: const <Photo>[], previews: <String, Uint8List>{}),
        failed: true,
      );
    }
  }

  Future<_Loaded<List<Comment>>> _comments(Story story) async {
    try {
      final rows = await ref
          .read(commentsRepositoryProvider)
          .listForStory(story.id);
      return (value: rows, failed: false);
    } catch (_) {
      // Shown as the reader's Try again SnackBar.
      return (value: const <Comment>[], failed: true);
    }
  }

  Future<_Loaded<List<Perspective>>> _perspectives(Story story) async {
    try {
      final rows = await ref
          .read(perspectivesRepositoryProvider)
          .listForStory(story.id);
      return (value: rows, failed: false);
    } catch (_) {
      // Shown as the reader's Try again SnackBar.
      return (value: const <Perspective>[], failed: true);
    }
  }

  Future<Uint8List?> _authorBytes(Story story) async {
    final avatarPath = story.authorAvatarPath;
    if (avatarPath == null) return null;
    try {
      return await ref
          .read(profileRepositoryProvider)
          .downloadAvatar(avatarPath);
    } catch (_) {
      // No avatar bytes: the meta line shows initials instead.
      return null;
    }
  }
}

/// Tree and steward lists are optional context; a failure leaves them empty.
Future<List<T>> _orEmpty<T>(Future<List<T>> Function() load) async {
  try {
    return await load();
  } on AppException {
    return const [];
  }
}

typedef _Loaded<T> = ({T value, bool failed});

typedef _Photos = ({List<Photo> photos, Map<String, Uint8List> previews});

typedef _Access = ({
  bool member,
  bool canWrite,
  List<TreeFamily> tree,
  List<StewardFamily> stewarded,
});

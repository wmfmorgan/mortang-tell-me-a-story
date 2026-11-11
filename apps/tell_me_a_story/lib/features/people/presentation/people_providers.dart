import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/person_profile.dart';
import 'package:tell_me_a_story/core/domain/person_story_card.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';

part 'people_providers.g.dart';

/// People in [familyId]'s tree, for the Add Person picker.
@riverpod
Future<List<Person>> treePeople(Ref ref, String familyId) {
  return ref.read(peopleRepositoryProvider).listTreePeople(familyId);
}

/// Everything the person profile card shows. [profile] null means missing.
@immutable
class PersonProfileView {
  const PersonProfileView({
    this.profile,
    this.editor,
    this.steward = false,
    this.picture,
    this.stories = const [],
  });

  final PersonProfile? profile;
  final Person? editor;
  final bool steward;
  final Uint8List? picture;
  final List<PersonStoryCard> stories;
}

/// Loads the profile card. Unreadable parts read as absent, as before.
@riverpod
Future<PersonProfileView> personProfileView(
  Ref ref,
  String personId,
  String? signedInUserId,
) async {
  final people = ref.read(peopleRepositoryProvider);
  final PersonProfile? loaded;
  try {
    loaded = await people.personProfile(personId);
  } catch (error) {
    // Unreadable profile renders as the missing card.
    return const PersonProfileView();
  }
  if (loaded == null) return const PersonProfileView();
  final profile = loaded;
  final editor = await _orNull(() => people.personForEdit(personId));
  final picture = await _orNull(
    () => people.pictureBytes(personId: personId, path: profile.avatarPath),
  );
  final stories =
      await _orNull(
        () => ref.read(storiesRepositoryProvider).storiesForPerson(personId),
      ) ??
      const <PersonStoryCard>[];
  final linkedId = editor?.userId;
  final steward =
      profile.isLinked && linkedId != null && linkedId != signedInUserId
      ? await people.isHomeFamilySteward(profile.familyId)
      : false;
  return PersonProfileView(
    profile: profile,
    editor: editor,
    steward: steward,
    picture: picture,
    stories: stories,
  );
}

/// Optional profile parts: a failed read shows the card without that part.
Future<T?> _orNull<T>(Future<T?> Function() read) async {
  try {
    return await read();
  } catch (error) {
    return null;
  }
}

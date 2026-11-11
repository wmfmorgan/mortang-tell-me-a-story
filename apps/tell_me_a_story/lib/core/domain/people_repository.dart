import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/person_profile.dart';

part 'people_repository.g.dart';

abstract class PeopleRepository {
  Future<List<Person>> listPeople(String familyId);

  /// People in [familyId]'s tree. Linked rows carry the account birth,
  /// coarsened by its visibility. The default reads [listPeople] so fakes
  /// stay unchanged.
  Future<List<Person>> listTreePeople(String familyId) => listPeople(familyId);

  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  });

  /// Tree-member row, including `userId` and `email`. Not [personProfile].
  Future<Person?> personForEdit(String personId) async => null;

  Future<PersonProfile?> personProfile(String personId) async => null;

  Future<Person> updatePerson({
    required String personId,
    required String name,
    bool passedAway = false,
    bool writePassedAway = false,
    String? about,
    bool writeAbout = false,
    String? email,
    bool writeEmail = false,
    List<int>? pictureBytes,
    bool clearPicture = false,
  }) async {
    throw UnimplementedError();
  }

  Future<List<Person>> listUnlinkedPeople(String familyId) async => const [];

  /// Home-family owner or co-owner. Other members, including owners of
  /// another family in the tree, are false.
  Future<bool> isHomeFamilySteward(String familyId) async => false;

  /// Sets or clears a linked person's passed-away flag (stewards only).
  Future<void> markPassedAway({required String personId, required bool value}) {
    throw UnimplementedError();
  }

  /// Picture bytes for the blob key [path] (a person's or a linked
  /// account's avatar). Null when there is no picture.
  Future<Uint8List?> pictureBytes({
    required String personId,
    String? path,
  }) async => null;
}

@Riverpod(keepAlive: true)
PeopleRepository peopleRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

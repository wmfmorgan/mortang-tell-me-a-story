import 'dart:typed_data';

import 'package:tell_me_a_story/data/comments_api.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/profile_api.dart';

import '../fakes/fake_invite_api.dart';

/// Quiet answers for family methods a test does not exercise.
/// [listFamilyTree] is the old gateway default: the matching row from
/// [FamiliesGateway.listMine], so marks stay empty until a fake returns a tree.
mixin QuietFamiliesDefaults on FamiliesGateway {
  @override
  Future<void> setFamilyOrigin({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<List<OriginDependent>> listOriginDependents(String storyId) async {
    return const [];
  }

  @override
  Future<List<FamilyPerson>> listMembers(String familyId) async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    final mine = await listMine();
    for (final row in mine) {
      if (row.id == familyId) {
        return [
          TreeFamily(
            id: row.id,
            name: row.name,
            parentFamilyId: row.parentFamilyId,
          ),
        ];
      }
    }
    return const [];
  }
}

/// Quiet answers for people methods a test does not exercise.
mixin QuietPeopleDefaults on PeopleGateway {
  @override
  Future<Person?> personForEdit(String personId) async => null;

  @override
  Future<PersonProfile?> personProfile(String personId) async => null;

  @override
  Future<List<Person>> listUnlinkedPeople(String familyId) async => const [];

  @override
  Future<bool> isHomeFamilySteward(String familyId) async => false;

  @override
  Future<String?> signedPictureUrl({
    required String personId,
    String? path,
  }) async => null;
}

/// Quiet [ProfileGateway.displayName] for tests that never show a posting name.
mixin QuietProfileDefaults on ProfileGateway {
  @override
  Future<String?> displayName(String userId) async => null;
}

class TestFamilies extends FamiliesGateway with QuietFamiliesDefaults {
  TestFamilies(this.rows);

  factory TestFamilies.member([String id = kTestFamilyId]) => TestFamilies([
    MemberFamily(id: id, name: id, createdAt: DateTime.utc(2020)),
  ]);

  final List<MemberFamily> rows;

  @override
  Future<List<MemberFamily>> listMine() async => rows;

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}

class QuietPhotos implements PhotosGateway {
  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);

  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {}

  @override
  Future<void> deletePhoto(Photo photo) async {}
}

class QuietComments implements CommentsGateway {
  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Comment>> listForStory(String storyId) async => const [];

  @override
  Future<void> update({required String id, required String body}) async {}
}

class QuietPerspectives implements PerspectivesGateway {
  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Perspective>> listForStory(String storyId) async => const [];

  @override
  Future<void> update({required String id, required String body}) async {}
}

class QuietPlaces implements PlacesGateway {
  @override
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async => null;

  @override
  Future<List<Place>> listFavorites(String familyId) async => const [];

  @override
  Future<List<Place>> listPlaces(String familyId) async => const [];

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      const [];

  @override
  Future<Place> markUsed(String placeId) => throw UnimplementedError();

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) => throw UnimplementedError();
}

class QuietPeople extends PeopleGateway with QuietPeopleDefaults {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) {
    throw UnimplementedError();
  }
}

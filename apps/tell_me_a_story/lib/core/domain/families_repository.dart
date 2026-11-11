import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/origin_dependent.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';

part 'families_repository.g.dart';

abstract class FamiliesRepository {
  Future<List<MemberFamily>> listMine();

  /// Owner and co-owner families, including soft-deleted rows still inside
  /// the 60-day window. Live member-only families are not included.
  Future<List<StewardFamily>> listStewarded();

  Future<void> setFamilyOrigin({
    required String familyId,
    required String storyId,
  }) async {}

  Future<List<OriginDependent>> listOriginDependents(String storyId) async {
    return const [];
  }

  /// Upload the hero, then store its object key. Tests that never save
  /// inherit the unimplemented default.
  Future<String> setCoverPhoto({
    required String familyId,
    required Uint8List bytes,
    String? previousPath,
  }) {
    throw UnimplementedError();
  }

  /// Delete the hero object and clear `cover_photo_path`.
  Future<void> clearCoverPhoto({
    required String familyId,
    required String? path,
  }) {
    throw UnimplementedError();
  }

  /// Live members of [familyId], with accounts. The default is empty so
  /// callers that do not open the create form stay quiet.
  Future<List<FamilyPerson>> listMembers(String familyId) async => const [];

  /// Live families in the session family's tree. The default is the current
  /// family only, so marks and the related menu stay empty until a caller
  /// returns the rest of the tree.
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

@Riverpod(keepAlive: true)
FamiliesRepository familiesRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

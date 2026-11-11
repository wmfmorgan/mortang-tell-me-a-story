import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';

part 'family_directory_repository.g.dart';

abstract class FamilyDirectoryRepository {
  Future<FamilyDirectory> listDirectory();
  Future<FamilyDetail?> loadDetail(String familyId);
}

@Riverpod(keepAlive: true)
FamilyDirectoryRepository familyDirectoryRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

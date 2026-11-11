import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/perspective.dart';

part 'perspectives_repository.g.dart';

abstract class PerspectivesRepository {
  Future<List<Perspective>> listForStory(String storyId);
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  });
  Future<void> update({required String id, required String body});
  Future<void> delete(String id);
}

@Riverpod(keepAlive: true)
PerspectivesRepository perspectivesRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

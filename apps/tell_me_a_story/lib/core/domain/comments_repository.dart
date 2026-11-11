import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/comment.dart';

part 'comments_repository.g.dart';

abstract class CommentsRepository {
  Future<List<Comment>> listForStory(String storyId);
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  });
  Future<void> update({required String id, required String body});
  Future<void> delete(String id);
}

@Riverpod(keepAlive: true)
CommentsRepository commentsRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

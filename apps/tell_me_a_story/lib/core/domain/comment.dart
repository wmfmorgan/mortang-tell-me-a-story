import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:tell_me_a_story/core/domain/display_name.dart';

part 'comment.freezed.dart';

/// Rejects empty / whitespace-only body before network.
void ensureValidCommentBody(String body) {
  if (body.trim().isEmpty) {
    throw ArgumentError.value(body, 'body', 'must not be empty');
  }
}

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String storyId,
    required String familyId,

    /// Null once the author's account is gone.
    required String? authorId,
    required String body,
    required DateTime createdAt,
    String? authorDisplayName,

    /// Server-computed for the caller: the author, or a steward of the story's
    /// family on a published story (D4).
    @Default(false) bool canDelete,
  }) = _Comment;

  const Comment._();

  String get authorLabel => displayNameOrMember(authorDisplayName);
}

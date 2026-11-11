import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';

/// Header "Start a timeline" from the Manage families pages. [onCreated]
/// reloads the host before the confirmation snack.
Future<void> startManageTimeline(
  BuildContext context,
  WidgetRef ref, {
  required String familyId,
  required String familyName,
  required String userId,
  required VoidCallback onCreated,
}) async {
  final published = await ref
      .read(storiesRepositoryProvider)
      .listPublished(familyId);
  if (!context.mounted) return;
  final created = await showStartTimelineDialog(
    context,
    parentId: familyId,
    parentName: familyName,
    stories: [
      for (final story in published)
        if (story.status == StoryStatus.published) story,
    ],
    currentUserId: userId,
    onWriteStory: () {
      if (!context.mounted) return;
      GoRouter.of(context)
          .push('${AppRoutes.newStory}?newTimelineFrom=$familyId');
    },
  );
  if (created == null || !context.mounted) return;
  onCreated();
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
}

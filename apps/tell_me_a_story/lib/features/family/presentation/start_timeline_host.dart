import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/data/manage_families_repository.dart';
import 'package:tell_me_a_story/core/data/people_repository.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';

/// Branch dialog shared by signed-in hosts. The caller reloads and snacks.
Future<StartTimelineResult?> openStartTimeline(
  BuildContext context, {
  required String parentId,
  required String parentName,
  required List<Story> stories,
  required String userId,
  required FamiliesRepository familiesApi,
  required PeopleRepository peopleApi,
  required ManageFamiliesRepository manageApi,
  Story? origin,
  bool allowChange = true,
}) {
  return showStartTimelineDialog(
    context,
    parentId: parentId,
    parentName: parentName,
    stories: stories,
    familiesApi: familiesApi,
    peopleApi: peopleApi,
    manageApi: manageApi,
    currentUserId: userId,
    origin: origin,
    allowChange: allowChange,
    onWriteStory: () {
      if (!context.mounted) return;
      GoRouter.of(context)
          .push('${AppRoutes.newStory}?newTimelineFrom=$parentId');
    },
  );
}

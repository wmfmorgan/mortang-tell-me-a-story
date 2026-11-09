import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family/start_timeline_dialog.dart';

/// Branch dialog shared by signed-in hosts. The caller reloads and snacks.
Future<StartTimelineResult?> openStartTimeline(
  BuildContext context, {
  required String parentId,
  required String parentName,
  required List<Story> stories,
  required String userId,
  required FamiliesGateway familiesApi,
  required PeopleGateway peopleApi,
  required ManageFamiliesGateway manageApi,
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

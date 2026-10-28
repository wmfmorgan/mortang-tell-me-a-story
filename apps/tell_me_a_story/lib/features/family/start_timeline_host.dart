import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';
import '../../data/families_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/people_api.dart';
import '../../data/stories_api.dart';
import 'start_timeline_dialog.dart';

/// Signed-in user id, or [override] when a host already has one.
String? signedInUserId({String? override}) {
  if (override != null) return override;
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

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
          .go('${AppRoutes.newStory}?newTimelineFrom=$parentId');
    },
  );
}

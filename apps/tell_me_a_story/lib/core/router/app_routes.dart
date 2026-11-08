import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Pops the current route, or opens the timeline when this page is the root.
void popOrGoTimeline(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.timeline);
    }
    return;
  }
  Navigator.of(context).pop();
}

/// Chrome-lock paths: sign-in entry (signed-out), `/family` (signed-in home).
abstract final class AppRoutes {
  static const signIn = '/';
  static const familyLanding = '/family';
  static const timeline = '/timeline';
  static const allStories = '/family/:id/stories';

  static String allStoriesPath(String familyId) => '/family/$familyId/stories';
  static const newStory = '/stories/new';
  static const story = '/stories/:storyId';
  static const storyEdit = '/stories/:storyId/edit';
  static const storyPerspective = '/stories/:storyId/perspective';
  static const invite = '/invite/:token';
  static const drafts = '/drafts';
  static const search = '/search';
  static const settings = '/settings';
  static const manageFamilies = '/manage-families';
  static const manageFamily = '/manage-families/:familyId';

  static String storyPath(String id) => '/stories/$id';

  static String storyEditPath(String id) => '/stories/$id/edit';

  static String invitePath(String token) => '/invite/$token';

  static String manageFamilyPath(String id) => '/manage-families/$id';

  static String storyPerspectivePath(String id) => '/stories/$id/perspective';
}

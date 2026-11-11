import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/session/server_timeline_live.dart';

part 'timeline_live.g.dart';

abstract class TimelineLive {
  void watch({required String familyId, required void Function() onChange});

  /// Reader feed for one story. The default does nothing so existing fakes
  /// keep compiling. The timeline [watch] stays on the family.
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  /// Whole-tree feed: every live family in [familyId]'s tree. The default
  /// does nothing, like [watchStory].
  void watchTree({
    required String familyId,
    required void Function() onChange,
  }) {}

  void dispose();
}

/// The live feed for the page that reads it; disposed with that page.
@riverpod
TimelineLive timelineLive(Ref ref) {
  final live = ServerTimelineLive();
  ref.onDispose(live.dispose);
  return live;
}

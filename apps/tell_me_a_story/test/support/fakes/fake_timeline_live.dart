import 'package:tell_me_a_story/core/session/timeline_live.dart';

/// No-op [TimelineLive] that records what was watched.
class FakeTimelineLive extends TimelineLive {
  final List<String> families = [];
  final List<String> stories = [];
  final List<String> trees = [];
  int disposeCalls = 0;

  @override
  void watch({required String familyId, required void Function() onChange}) {
    families.add(familyId);
  }

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {
    stories.add(storyId);
  }

  @override
  void watchTree({
    required String familyId,
    required void Function() onChange,
  }) {
    trees.add(familyId);
  }

  @override
  void dispose() {
    disposeCalls++;
  }
}

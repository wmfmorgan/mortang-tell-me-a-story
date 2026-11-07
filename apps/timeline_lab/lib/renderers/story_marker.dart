import '../filter/timeline_filter.dart';
import '../model/lab_models.dart';
import '../theme/lab_theme.dart';

// Story dots are terracotta in every renderer; family shows through lanes
// and labels, and moss is reserved for origin rings (Decision D2,
// docs/ux/branch-callout.md Rule 4 "One green").

/// True when some branch family starts at this story.
bool isOrigin(LabStory s, LabDataset d) =>
    d.families.values.any((f) => f.originStoryId == s.id);

double entryOpacity(TimelineEntry e) => e.matched ? 1 : labDimOpacity;

/// Family ids in lane order: root first, then branches by branch year.
List<String> familyLaneOrder(LabDataset d) {
  final fams = d.families.values.toList()
    ..sort((a, b) => (a.branchYear ?? 0).compareTo(b.branchYear ?? 0));
  return [for (final f in fams) f.id];
}

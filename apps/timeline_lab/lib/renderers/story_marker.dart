import 'package:flutter/painting.dart';

import '../filter/timeline_filter.dart';
import '../model/lab_models.dart';
import '../theme/lab_theme.dart';

/// Root family → terracotta, Reyes → sage, Okafor → moss.
Color markerColor(LabStory s, LabDataset d) => switch (s.familyId) {
  'fam-reyes' => labSage,
  'fam-okafor' => labMoss,
  _ => labTerracotta,
};

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

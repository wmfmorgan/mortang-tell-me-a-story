import 'package:flutter/widgets.dart';

import '../filter/timeline_filter.dart';
import '../model/lab_models.dart';
import '../playback/playback_controller.dart';
import 'render_box_layout_renderer.dart';
import 'sliver_list_renderer.dart';
import 'swimlanes_renderer.dart';
import 'tree_graph_renderer.dart';
import 'treemap_renderer.dart';
import 'zoom_canvas_renderer.dart';

enum RendererKind {
  sliverList,
  renderBoxLayout,
  zoomCanvas,
  swimlanes,
  treeGraph,
  treemap;

  String get label => switch (this) {
    sliverList => 'Sliver list',
    renderBoxLayout => 'RenderBox layout',
    zoomCanvas => 'Zoom canvas',
    swimlanes => 'Swimlanes',
    treeGraph => 'Tree graph',
    treemap => 'Treemap',
  };
}

/// Everything a renderer gets. Entries are already filtered (hide) or
/// flagged (dim); renderers never re-run the filter.
class TimelineViewData {
  const TimelineViewData({
    required this.dataset,
    required this.entries,
    required this.mode,
    required this.selectedId,
    required this.onSelect,
    this.playback,
  });

  final LabDataset dataset;

  /// Ascending dataset order.
  final List<TimelineEntry> entries;
  final FilterMode mode;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Optional playback. Renderers lay out every entry and use
  /// `playback.reveal(id)` for visibility and `playback.cursorYear` for the
  /// time cursor; they listen to it directly instead of rebuilding. When
  /// null or idle, everything is shown.
  final PlaybackController? playback;

  /// Dim mode with at least one unmatched entry: the only state where
  /// renderers should emphasise matches.
  bool get anyDimmed => entries.any((e) => !e.matched);

  /// Newest matched story, or the newest story when nothing matched. Used
  /// by horizontal renderers to pick their initial scroll position.
  LabStory? get newestMatched {
    for (final e in entries.reversed) {
      if (e.matched) return e.story;
    }
    return entries.isEmpty ? null : entries.last.story;
  }
}

Widget buildRenderer(RendererKind kind, TimelineViewData data) =>
    switch (kind) {
      RendererKind.sliverList => SliverListTimeline(data: data),
      RendererKind.renderBoxLayout => RenderBoxTimeline(data: data),
      RendererKind.zoomCanvas => ZoomCanvasTimeline(data: data),
      RendererKind.swimlanes => SwimlanesTimeline(data: data),
      RendererKind.treeGraph => TreeGraphTimeline(data: data),
      RendererKind.treemap => TreemapTimeline(data: data),
    };

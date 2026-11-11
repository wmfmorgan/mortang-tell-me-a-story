import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';
import 'package:tell_me_a_story/core/widgets/timeline/view_switch.dart';

/// The zoom last shown. Each zoom replaces the rail (and its switch), so
/// the new switch's pill slides in from this segment.
TimelineZoom? _lastZoom;

class DialSubheader extends StatelessWidget {
  const DialSubheader({
    super.key,
    required this.selected,
    required this.onMacro,
    required this.onMid,
    required this.onFullCards,
    this.action,
  });

  final TimelineZoom selected;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  /// Beside the zoom switch: the subheader's action buttons.
  final Widget? action;

  static String _labelOf(TimelineZoom zoom) => switch (zoom) {
    TimelineZoom.far => 'Decades',
    TimelineZoom.mid => 'Years',
    TimelineZoom.near => 'Days',
  };

  static Key _segmentKeyOf(TimelineZoom zoom) => switch (zoom) {
    TimelineZoom.far => const Key('timeline-zoom-macro'),
    TimelineZoom.mid => const Key('timeline-zoom-mid'),
    TimelineZoom.near => const Key('timeline-zoom-full'),
  };

  void _onChanged(TimelineZoom zoom) {
    switch (zoom) {
      case TimelineZoom.far:
        onMacro();
      case TimelineZoom.mid:
        onMid();
      case TimelineZoom.near:
        onFullCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slideFrom = _lastZoom;
    _lastZoom = selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: AlbumSpace.l),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: AlbumSpace.m,
        spacing: AlbumSpace.l,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AlbumSpace.m,
            runSpacing: AlbumSpace.s,
            children: [
              ?action,
              ViewSwitch<TimelineZoom>(
                values: TimelineZoom.values,
                labelOf: _labelOf,
                selected: selected,
                onChanged: _onChanged,
                segmentKeyOf: _segmentKeyOf,
                slideFrom: slideFrom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

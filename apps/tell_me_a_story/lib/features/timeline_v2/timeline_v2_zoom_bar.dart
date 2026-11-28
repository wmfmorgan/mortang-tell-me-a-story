import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../timeline/timeline_zoom.dart';

/// Stadium zoom control from the phase 7 restyle, plus the Filters button.
class TimelineV2ZoomBar extends StatelessWidget {
  const TimelineV2ZoomBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onFilters,
    required this.filterActive,
  });

  final TimelineZoom selected;
  final ValueChanged<TimelineZoom> onSelected;
  final VoidCallback onFilters;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _ZoomTrack(selected: selected, onSelected: onSelected),
          const SizedBox(width: 12),
          TextButton.icon(
            key: const Key('timeline-v2-filters-open'),
            onPressed: onFilters,
            icon: Icon(filterActive ? Icons.filter_alt : Icons.tune),
            label: const Text('Filters'),
          ),
        ],
      ),
    );
  }
}

class _ZoomTrack extends StatelessWidget {
  const _ZoomTrack({required this.selected, required this.onSelected});

  final TimelineZoom selected;
  final ValueChanged<TimelineZoom> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: albumPillFill,
        shape: StadiumBorder(side: BorderSide(color: albumPillBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomSegment(
              zoom: TimelineZoom.far,
              label: 'Decades',
              segmentKey: 'timeline-v2-zoom-decades',
              selected: selected,
              onSelected: onSelected,
            ),
            _ZoomSegment(
              zoom: TimelineZoom.mid,
              label: 'Years',
              segmentKey: 'timeline-v2-zoom-years',
              selected: selected,
              onSelected: onSelected,
            ),
            _ZoomSegment(
              zoom: TimelineZoom.near,
              label: 'Days',
              segmentKey: 'timeline-v2-zoom-days',
              selected: selected,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomSegment extends StatelessWidget {
  const _ZoomSegment({
    required this.zoom,
    required this.label,
    required this.segmentKey,
    required this.selected,
    required this.onSelected,
  });

  final TimelineZoom zoom;
  final String label;
  final String segmentKey;
  final TimelineZoom selected;
  final ValueChanged<TimelineZoom> onSelected;

  @override
  Widget build(BuildContext context) {
    final on = zoom == selected;
    return TextButton(
      key: Key(segmentKey),
      onPressed: on ? () {} : () => onSelected(zoom),
      style: TextButton.styleFrom(
        backgroundColor: on ? albumTerracotta : albumBackdropClear,
        foregroundColor: on ? albumParchment : albumInk,
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

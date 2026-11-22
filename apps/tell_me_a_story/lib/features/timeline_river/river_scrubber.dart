import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'river_beat.dart';
import 'river_filter.dart';

/// Decade ticks. Matching decades are filled. The rest are outlined.
class RiverScrubber extends StatelessWidget {
  const RiverScrubber({
    super.key,
    required this.stories,
    required this.filter,
    required this.showingDecade,
    required this.axis,
    required this.onSelect,
  });

  final List<Story> stories;
  final RiverFilter filter;
  final int showingDecade;
  final Axis axis;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final decades = _decades();
    if (decades.isEmpty) return const SizedBox.shrink();
    final label = riverScrubberLabel(
      oldestDecade: decades.first.year,
      newestDecade: decades.last.year,
      showingDecade: showingDecade,
    );
    return Semantics(
      slider: true,
      label: label,
      onIncrease: () => _step(decades, 1),
      onDecrease: () => _step(decades, -1),
      child: ExcludeSemantics(child: _track(decades)),
    );
  }

  List<_DecadeBump> _decades() {
    final grouped = <int, List<Story>>{};
    for (final story in stories) {
      final year = decadeStartYear(story.publishedStart);
      (grouped[year] ??= []).add(story);
    }
    final years = grouped.keys.toList()..sort();
    return [
      for (final year in years)
        _DecadeBump(
          year: year,
          count: grouped[year]!.length,
          matches: grouped[year]!.any(filter.matches),
        ),
    ];
  }

  void _step(List<_DecadeBump> decades, int delta) {
    final index = decades.indexWhere((row) => row.year == showingDecade);
    final next = (index < 0 ? 0 : index + delta).clamp(0, decades.length - 1);
    onSelect(decades[next].year);
  }

  Widget _track(List<_DecadeBump> decades) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = axis == Axis.vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final each = math.max(44.0, extent / decades.length);
        return _bar(decades, each);
      },
    );
  }

  Widget _bar(List<_DecadeBump> decades, double each) {
    final children = [
      for (final row in decades)
        SizedBox(
          width: axis == Axis.horizontal ? each : null,
          height: axis == Axis.vertical ? each : null,
          child: _bump(row),
        ),
    ];
    final bar = axis == Axis.vertical
        ? Column(children: children)
        : Row(children: children);
    return SingleChildScrollView(scrollDirection: axis, child: bar);
  }

  Widget _bump(_DecadeBump row) {
    final active = row.year == showingDecade;
    return Semantics(
      button: true,
      label: '${row.year}s',
      child: GestureDetector(
        key: Key('river-scrub-${row.year}'),
        onTap: () => onSelect(row.year),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active
                  ? albumTerracotta.withValues(alpha: 0.28)
                  : albumBackdropClear,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: albumTerracotta, width: active ? 2 : 1),
            ),
            child: Center(child: _mark(row)),
          ),
        ),
      ),
    );
  }

  Widget _mark(_DecadeBump row) {
    final thickness = 8.0 + (row.count * 4);
    final mark = thickness.clamp(8.0, 36.0).toDouble();
    return Container(
      width: axis == Axis.vertical ? mark : 18,
      height: axis == Axis.horizontal ? mark.clamp(8.0, 28.0).toDouble() : 18,
      decoration: BoxDecoration(
        color: row.matches ? albumTerracotta : albumBackdropClear,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: albumTerracotta),
      ),
    );
  }
}

class _DecadeBump {
  const _DecadeBump({
    required this.year,
    required this.count,
    required this.matches,
  });

  final int year;
  final int count;
  final bool matches;
}

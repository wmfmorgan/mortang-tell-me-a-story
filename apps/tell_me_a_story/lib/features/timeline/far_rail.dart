import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'dial_subheader.dart';
import 'far_decade_row.dart';
import 'timeline_arrow_keys.dart';
import 'callout_layout.dart';
import 'timeline_empty_tap.dart';
import 'timeline_zoom.dart';

class FarRail extends StatefulWidget {
  const FarRail({
    super.key,
    required this.bands,
    required this.focusedId,
    required this.branching,
    this.originStoryId,
    required this.onDot,
    required this.onEmpty,
    required this.onYear,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMid,
    required this.onFullCards,
  });

  final List<DecadeBand> bands;
  final String? focusedId;
  final RailBranching branching;
  final String? originStoryId;
  final ValueChanged<Story> onDot;
  final VoidCallback onEmpty;
  final ValueChanged<int> onYear;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  State<FarRail> createState() => _FarRailState();
}

class _FarRailState extends State<FarRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  int? _centerYear;
  Map<int, double> _opacities = const {};
  var _centered = false;

  GlobalKey _rowKey(int year) => _rowKeys.putIfAbsent(year, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _centerYear = _yearOf(widget.focusedId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final bands = widget.bands;
    if (bands.isEmpty) return;
    final current = _centerYear ?? bands[bands.length ~/ 2].startYear;
    var index = bands.indexWhere((band) => band.startYear == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= bands.length
        ? null
        : _rowKey(bands[next].startYear).currentContext;
    scrollDialStep(controller: _scroll, direction: direction, target: target);
  }

  @override
  void didUpdateWidget(covariant FarRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final year = _yearOf(widget.focusedId);
    if (year != null &&
        year != _yearOf(oldWidget.focusedId) &&
        year != _centerYear) {
      _centerYear = year;
      _centerOn(year);
    }
  }

  int? _yearOf(String? id) {
    if (id == null) return null;
    for (final band in widget.bands) {
      for (final story in band.stories) {
        if (story.id == id) return band.startYear;
      }
    }
    return null;
  }

  Story? _highlight(DecadeBand band) {
    for (final story in band.stories) {
      if (story.id == widget.focusedId) return story;
    }
    if (band.stories.isEmpty) return null;
    return band.stories[band.stories.length ~/ 2];
  }

  void _centerInitial() {
    if (!mounted || _centered || widget.bands.isEmpty) return;
    _centered = true;
    final year =
        _centerYear ?? widget.bands[widget.bands.length ~/ 2].startYear;
    _centerYear = year;
    _centerOn(year);
  }

  void _centerOn(int year) {
    final target = _rowKey(year).currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final centerY = viewportTop + viewport.size.height / 2;
    int? bestYear;
    var best = double.infinity;
    final opacities = <int, double>{};
    for (final band in widget.bands) {
      final row =
          _rowKey(band.startYear).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final rowTop = row.localToGlobal(Offset.zero).dy;
      final mid = rowTop + row.size.height / 2;
      final distance = (mid - centerY).abs();
      opacities[band.startYear] = farEdgeOpacity(
        rowTop: rowTop,
        rowHeight: row.size.height,
        viewportTop: viewportTop,
        viewportHeight: viewport.size.height,
      );
      if (distance < best) {
        best = distance;
        bestYear = band.startYear;
      }
    }
    final yearChanged = bestYear != null && bestYear != _centerYear;
    if (!yearChanged && _sameOpacity(opacities)) return;
    setState(() {
      if (bestYear != null) _centerYear = bestYear;
      _opacities = opacities;
    });
    DecadeBand? band;
    for (final candidate in widget.bands) {
      if (candidate.startYear == bestYear) band = candidate;
    }
    final story = band == null ? null : _highlight(band);
    final id = story?.id;
    if (!yearChanged) return;
    if (id != null && id != widget.focusedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != widget.focusedId) widget.onFocus(id);
      });
    }
  }

  bool _sameOpacity(Map<int, double> next) {
    if (next.length != _opacities.length) return false;
    for (final entry in next.entries) {
      final previous = _opacities[entry.key];
      if (previous == null || (previous - entry.value).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  List<Widget> _farChildren() {
    return [
      for (final band in widget.bands)
        FarDecadeRow(
          key: _rowKey(band.startYear),
          band: band,
          branching: widget.branching,
          originStoryId: widget.originStoryId,
          onOpenBranch: widget.onOpenBranch,
          focused: band.startYear == _centerYear,
          opacity: _opacities[band.startYear] ?? 1,
          highlight: _highlight(band),
          onDot: widget.onDot,
          onYear: widget.onYear,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ArrowKeys(
      onStep: _step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: DialSubheader(
              selected: TimelineZoom.far,
              onMacro: () {},
              onMid: widget.onMid,
              onFullCards: widget.onFullCards,
            ),
          ),
          Expanded(
            child: EmptyTap(
              onTap: widget.onEmpty,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollEndNotification) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _measure();
                    });
                  }
                  return false;
                },
                child: Stack(
                  key: _viewportKey,
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            width: 2,
                            child: ColoredBox(color: albumInkFaint),
                          ),
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final pad = constraints.maxHeight / 2;
                        return ListView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                          children: _farChildren(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

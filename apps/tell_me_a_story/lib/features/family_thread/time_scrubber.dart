import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'thread_beat_model.dart';
import 'thread_filter.dart';
import 'thread_focus.dart';

const _handleExtent = 44.0;

class TimeScrubber extends StatefulWidget {
  const TimeScrubber({
    super.key,
    required this.stories,
    required this.focusStoryId,
    required this.vertical,
    required this.onPreview,
    required this.onCommit,
    this.filter = ThreadFilter.cleared,
  });

  final List<Story> stories;
  final ThreadFilter filter;
  final String? focusStoryId;
  final bool vertical;
  final ValueChanged<String> onPreview;
  final ValueChanged<String> onCommit;

  @override
  State<TimeScrubber> createState() => _TimeScrubberState();
}

class _TimeScrubberState extends State<TimeScrubber> {
  final _focus = FocusNode(debugLabel: 'time-scrubber');
  String? _dragId;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<_Tick> _ticks() => _ticksOf(widget.stories, widget.filter);

  @override
  Widget build(BuildContext context) {
    final ticks = _ticks();
    if (ticks.isEmpty) return const SizedBox.shrink();
    final showing = _decadeOf(ticks, widget.focusStoryId);
    return Semantics(
      container: true,
      slider: true,
      label: FamilyThreadCopy.scrubberSlider(
        oldest: ticks.first.decade,
        newest: ticks.last.decade,
        showing: showing,
      ),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: (_) => _focus.requestFocus(),
          child: _Track(
            ticks: ticks,
            vertical: widget.vertical,
            showing: showing,
            onTap: _tap,
            onDrag: _drag,
            onRelease: _release,
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final delta = _keyDelta(event.logicalKey);
    if (delta == null) return KeyEventResult.ignored;
    final id = _stepId(_ticks(), widget.focusStoryId, delta, widget.filter);
    if (id != null) widget.onCommit(id);
    return KeyEventResult.handled;
  }

  void _tap(double t) {
    final ticks = _ticks();
    final id = _tapPick(
      ticks,
      t,
      widget.filter,
      _anchorOf(ticks, widget.focusStoryId),
    )?.id;
    if (id != null) widget.onCommit(id);
  }

  void _drag(double t) {
    final id = _dragPick(_ticks(), t, widget.filter)?.id;
    if (id == null) return;
    _dragId = id;
    widget.onPreview(id);
  }

  void _release() {
    final id = _dragId;
    _dragId = null;
    if (id != null) widget.onCommit(id);
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.ticks,
    required this.vertical,
    required this.showing,
    required this.onTap,
    required this.onDrag,
    required this.onRelease,
  });

  final List<_Tick> ticks;
  final bool vertical;
  final int showing;
  final ValueChanged<double> onTap;
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => onTap(_fraction(details.localPosition, size)),
          onPanStart: (details) =>
              onDrag(_fraction(details.localPosition, size)),
          onPanUpdate: (details) =>
              onDrag(_fraction(details.localPosition, size)),
          onPanEnd: (_) => onRelease(),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned.fill(child: _lane()),
                _handle(size),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lane() {
    return Flex(
      key: const Key('scrubber-ticks'),
      direction: vertical ? Axis.vertical : Axis.horizontal,
      children: [
        for (final tick in ticks)
          Expanded(
            flex: tick.total,
            child: _Bump(
              label: FamilyThreadCopy.scrubberTick(tick.decade),
              total: tick.total,
              matched: tick.matched,
              vertical: vertical,
              focused: tick.decade == showing,
            ),
          ),
      ],
    );
  }

  Widget _handle(Size size) {
    final along = vertical ? size.height : size.width;
    final cross = vertical ? size.width : size.height;
    final start = _handleStart(along, _centerFraction(ticks, showing));
    final crossStart = ((cross - _handleExtent) / 2).clamp(0.0, cross);
    return Positioned(
      left: vertical ? crossStart : start,
      top: vertical ? start : crossStart,
      child: _Handle(label: FamilyThreadCopy.scrubberTick(showing)),
    );
  }

  double _fraction(Offset local, Size size) {
    final span = vertical ? size.height : size.width;
    if (span <= 0) return 0;
    final delta = vertical ? local.dy : local.dx;
    return (delta / span).clamp(0.0, 1.0);
  }
}

class _Bump extends StatelessWidget {
  const _Bump({
    required this.label,
    required this.total,
    required this.matched,
    required this.vertical,
    required this.focused,
  });

  final String label;
  final int total;
  final int matched;
  final bool vertical;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: focused ? BorderRadius.circular(8) : null,
        border: _border(),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Fill(matched: matched, total: total, vertical: vertical),
          Center(child: Text(label, maxLines: 1, style: _tickStyle(context))),
        ],
      ),
    );
  }

  Border? _border() {
    if (focused) return Border.all(color: albumTerracotta, width: 2);
    if (matched == total) return null;
    return Border.all(color: albumInkDim);
  }
}

class _Fill extends StatelessWidget {
  const _Fill({
    required this.matched,
    required this.total,
    required this.vertical,
  });

  final int matched;
  final int total;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (matched == 0 || total == 0) return const SizedBox.expand();
    final factor = matched / total;
    return FractionallySizedBox(
      alignment: vertical ? Alignment.topCenter : Alignment.centerLeft,
      widthFactor: vertical ? 1 : factor,
      heightFactor: vertical ? factor : 1,
      child: const ColoredBox(color: albumInkDim),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _handleExtent,
      height: _handleExtent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: albumTerracotta, width: 2),
        ),
        child: _grip(context),
      ),
    );
  }

  Widget _grip(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: albumTerracotta,
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 12, height: 12),
        ),
        Text(
          label,
          key: const Key('scrubber-handle'),
          style: _tickStyle(context),
        ),
      ],
    );
  }
}

class _Tick {
  _Tick(this.decade, this.stories, ThreadFilter filter)
    : matched = stories.where(filter.matches).length;

  final int decade;
  final List<Story> stories;
  final int matched;

  int get total => stories.length;
}

TextStyle? _tickStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.copyWith(color: albumInkDim);
}

List<_Tick> _ticksOf(List<Story> stories, ThreadFilter filter) {
  final grouped = <int, List<Story>>{};
  for (final story in stories) {
    (grouped[threadDecadeOf(story)] ??= <Story>[]).add(story);
  }
  return [
    for (final entry in grouped.entries) _Tick(entry.key, entry.value, filter),
  ];
}

int _decadeOf(List<_Tick> ticks, String? focusId) {
  for (final tick in ticks) {
    if (tick.stories.any((story) => story.id == focusId)) return tick.decade;
  }
  return ticks.last.decade;
}

DateTime _anchorOf(List<_Tick> ticks, String? focusId) {
  for (final tick in ticks) {
    for (final story in tick.stories) {
      if (story.id == focusId) return story.publishedStart;
    }
  }
  return ticks.last.stories.last.publishedStart;
}

Story? _nearest(List<Story> stories, ThreadFilter filter, DateTime anchor) {
  final matched = [
    for (final story in stories)
      if (filter.matches(story)) story,
  ];
  return ThreadFocus.nearestInTime(matched, anchor);
}

Story? _tapPick(
  List<_Tick> ticks,
  double t,
  ThreadFilter filter,
  DateTime anchor,
) {
  if (ticks.isEmpty) return null;
  final tick = ticks[_tickSpot(t, ticks)];
  final inside = _nearest(tick.stories, filter, anchor);
  if (inside != null) return inside;
  final matched = [
    for (final item in ticks)
      for (final story in item.stories)
        if (filter.matches(story)) story,
  ];
  return ThreadFocus.nearestInTime(matched, DateTime.utc(tick.decade + 5));
}

Story? _dragPick(List<_Tick> ticks, double t, ThreadFilter filter) {
  final stories = [for (final tick in ticks) ...tick.stories];
  if (stories.isEmpty) return null;
  final story = stories[_spot(t, stories.length)];
  if (filter.matches(story)) return story;
  return ThreadFocus.nearestInTime([
    for (final item in stories)
      if (filter.matches(item)) item,
  ], story.publishedStart);
}

String? _stepId(
  List<_Tick> ticks,
  String? focusId,
  int delta,
  ThreadFilter filter,
) {
  if (ticks.isEmpty || delta == 0) return null;
  var index = _decadeIndex(ticks, focusId);
  final toward = delta < 0 ? -1 : 1;
  var left = delta.abs();
  while (left > 0) {
    final next = _matchingStep(ticks, index, toward);
    if (next == null) break;
    index = next;
    left -= 1;
  }
  return _nearest(ticks[index].stories, filter, _anchorOf(ticks, focusId))?.id;
}

int _decadeIndex(List<_Tick> ticks, String? focusId) {
  for (var i = 0; i < ticks.length; i++) {
    if (ticks[i].stories.any((story) => story.id == focusId)) return i;
  }
  return ticks.length - 1;
}

int? _matchingStep(List<_Tick> ticks, int index, int toward) {
  var next = index + toward;
  while (next >= 0 && next < ticks.length && ticks[next].matched == 0) {
    next += toward;
  }
  if (next < 0 || next >= ticks.length) return null;
  return next;
}

int _tickSpot(double t, List<_Tick> ticks) {
  final total = ticks.fold<int>(0, (sum, tick) => sum + tick.total);
  if (total <= 1) return 0;
  var cursor = 0;
  final target = t.clamp(0.0, 1.0) * total;
  for (var i = 0; i < ticks.length; i++) {
    cursor += ticks[i].total;
    if (target < cursor || i == ticks.length - 1) return i;
  }
  return 0;
}

int _spot(double t, int count) {
  if (count <= 1) return 0;
  return (t.clamp(0.0, 1.0) * (count - 1)).round().clamp(0, count - 1);
}

double _centerFraction(List<_Tick> ticks, int decade) {
  final total = ticks.fold<int>(0, (sum, tick) => sum + tick.total);
  if (total == 0) return 0;
  var before = 0;
  for (final tick in ticks) {
    if (tick.decade == decade) return (before + tick.total / 2) / total;
    before += tick.total;
  }
  return 1;
}

double _handleStart(double span, double fraction) {
  final room = span - _handleExtent;
  if (room <= 0) return 0;
  return (span * fraction - _handleExtent / 2).clamp(0.0, room);
}

int? _keyDelta(LogicalKeyboardKey key) {
  return switch (key) {
    LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowLeft => -1,
    LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowRight => 1,
    LogicalKeyboardKey.pageUp => -2,
    LogicalKeyboardKey.pageDown => 2,
    _ => null,
  };
}

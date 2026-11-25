import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'thread_filter.dart';
import 'time_scrubber_model.dart';

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
  final ValueChanged<String?> onPreview;
  final ValueChanged<String> onCommit;

  @override
  State<TimeScrubber> createState() => _TimeScrubberState();
}

class _TimeScrubberState extends State<TimeScrubber> {
  final _focus = FocusNode(debugLabel: 'time-scrubber');
  String? _dragId;
  var _pointerCancelled = false;

  TimeScrubberModel get _model =>
      TimeScrubberModel.build(widget.stories, widget.filter);

  @override
  void dispose() {
    final preview = widget.onPreview;
    final pending = _dragId != null;
    _dragId = null;
    _focus.dispose();
    super.dispose();
    if (!pending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => preview(null));
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    if (model.isEmpty) return const SizedBox.shrink();
    final showing = model.showingDecade(widget.focusStoryId);
    return Semantics(
      container: true,
      slider: true,
      label: FamilyThreadCopy.scrubberSlider(
        oldest: model.decadeAt(0),
        newest: model.decadeAt(model.tickCount - 1),
        showing: showing,
      ),
      onIncrease: () => _commitStep(1),
      onDecrease: () => _commitStep(-1),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: (_) => _focus.requestFocus(),
          child: _Track(
            model: model,
            vertical: widget.vertical,
            showing: showing,
            onTap: _tap,
            onDrag: _drag,
            onFinish: _finishDrag,
            onCancel: _cancelDrag,
            onPointerCancel: () => _pointerCancelled = true,
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final delta = TimeScrubberModel.keyDelta(event.logicalKey);
    if (delta == null) return KeyEventResult.ignored;
    _commitStep(delta);
    return KeyEventResult.handled;
  }

  void _commitStep(int delta) {
    final id = _model.stepId(widget.focusStoryId, delta);
    if (id != null) widget.onCommit(id);
  }

  void _tap(double t) {
    final id = _model.tapPick(t, widget.focusStoryId)?.id;
    if (id != null) widget.onCommit(id);
  }

  void _drag(double t) {
    final id = _model.dragPick(t)?.id;
    if (id == null) return;
    _dragId = id;
    widget.onPreview(id);
  }

  void _finishDrag() {
    final id = _dragId;
    final cancelled = _pointerCancelled;
    _dragId = null;
    _pointerCancelled = false;
    if (cancelled) {
      widget.onPreview(null);
      return;
    }
    if (id != null) widget.onCommit(id);
  }

  void _cancelDrag() {
    if (_dragId == null) return;
    _dragId = null;
    _pointerCancelled = false;
    widget.onPreview(null);
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.model,
    required this.vertical,
    required this.showing,
    required this.onTap,
    required this.onDrag,
    required this.onFinish,
    required this.onCancel,
    required this.onPointerCancel,
  });

  final TimeScrubberModel model;
  final bool vertical;
  final int showing;
  final ValueChanged<double> onTap;
  final ValueChanged<double> onDrag;
  final VoidCallback onFinish;
  final VoidCallback onCancel;
  final VoidCallback onPointerCancel;

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
          onPanEnd: (_) => onFinish(),
          onPanCancel: onCancel,
          child: Listener(
            onPointerCancel: (_) => onPointerCancel(),
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  Positioned.fill(child: _lane()),
                  _handle(size),
                ],
              ),
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
        for (var i = 0; i < model.tickCount; i++)
          Expanded(
            flex: model.totalAt(i),
            child: _Bump(
              label: FamilyThreadCopy.scrubberTick(model.decadeAt(i)),
              total: model.totalAt(i),
              matched: model.matchedAt(i),
              vertical: vertical,
              focused: model.decadeAt(i) == showing,
            ),
          ),
      ],
    );
  }

  Widget _handle(Size size) {
    final along = vertical ? size.height : size.width;
    final cross = vertical ? size.width : size.height;
    final start = TimeScrubberModel.handleStart(
      along,
      model.centerFraction(showing),
    );
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

const _handleExtent = 44.0;

TextStyle? _tickStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.copyWith(color: albumInkDim);
}

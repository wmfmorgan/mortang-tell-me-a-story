import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// The app's one segmented control: a labelled row of segments with a
/// terracotta pill that slides to the selected one. Scrolls sideways on
/// narrow screens instead of overflowing.
///
/// Tests read [selected] through `tester.widget<ViewSwitch<T>>` on the
/// switch's `key`; each segment carries [segmentKeyOf] and reports
/// `selected` to semantics.
class ViewSwitch<T> extends StatefulWidget {
  const ViewSwitch({
    super.key,
    this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.segmentKeyOf,
    this.slideFrom,
    this.leading = const [],
    this.trailing = const [],
  });

  /// Shown before the segments. Null when the segment names say it all.
  final String? label;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Key for each segment's tappable.
  final Key Function(T)? segmentKeyOf;

  /// When set (and not [selected]), the pill slides in from this value's
  /// segment on first layout: for hosts that rebuild the switch per value.
  final T? slideFrom;

  /// Shown before the label and segments (another switch sharing the row).
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  State<ViewSwitch<T>> createState() => _ViewSwitchState<T>();
}

class _ViewSwitchState<T> extends State<ViewSwitch<T>>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  late List<GlobalKey> _keys;
  late final AnimationController _controller;
  late int _fromIndex;
  late int _toIndex;
  Rect? _fromRect;
  Rect? _toRect;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _keys = _segmentKeys(widget.values.length);
    _toIndex = _indexOf(widget.selected);
    final from = widget.slideFrom;
    _fromIndex = from == null ? _toIndex : _indexOf(from);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  static List<GlobalKey> _segmentKeys(int n) =>
      List<GlobalKey>.generate(n, (_) => GlobalKey());

  /// Unknown values fall back to the first segment.
  int _indexOf(T value) {
    final i = widget.values.indexOf(value);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(covariant ViewSwitch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length) {
      _keys = _segmentKeys(widget.values.length);
    }
    if (oldWidget.selected == widget.selected &&
        oldWidget.values.length == widget.values.length) {
      return;
    }
    final from = oldWidget.values.indexOf(oldWidget.selected);
    _toIndex = _indexOf(widget.selected);
    _fromIndex = from < 0 || from >= widget.values.length ? _toIndex : from;
    _fromRect = null;
    _toRect = null;
    _started = false;
    _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _localRect(int index) {
    final box = _keys[index].currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize || !stack.hasSize) {
      return null;
    }
    final topLeft = stack.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  void _place() {
    if (!mounted || widget.values.isEmpty) return;
    final from = _localRect(_fromIndex);
    final to = _localRect(_toIndex);
    if (from == null || to == null) return;
    if (_fromRect == from && _toRect == to) return;
    setState(() {
      _fromRect = from;
      _toRect = to;
    });
    if (_started || _fromIndex == _toIndex) return;
    _started = true;
    _controller.forward(from: 0);
  }

  double get _t => _fromIndex == _toIndex
      ? 1.0
      : Curves.easeOutCubic.transform(_controller.value);

  Color _foreground(int index) {
    final t = _t;
    if (index == _toIndex && index == _fromIndex) return albumOnAccent;
    // Color.lerp returns null only when both ends are null; both are tokens,
    // so the fallbacks never apply.
    if (index == _toIndex) {
      return Color.lerp(albumInk, albumOnAccent, t) ?? albumOnAccent;
    }
    if (index == _fromIndex) {
      return Color.lerp(albumOnAccent, albumInk, t) ?? albumInk;
    }
    return albumInk;
  }

  Rect? _pillRect() => _fromRect == null || _toRect == null
      ? null
      : Rect.lerp(_fromRect, _toRect, _t);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
    final label = widget.label;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AlbumSpace.l,
        vertical: AlbumSpace.s,
      ),
      child: Row(
        children: [
          ...widget.leading,
          if (label != null) ...[
            Text(label, style: AlbumText.lane(Theme.of(context).textTheme)),
            const SizedBox(width: AlbumSpace.m),
          ],
          _SegmentTrack(
            animation: _controller,
            stackKey: _stackKey,
            pillRect: _pillRect,
            segments: () => _SegmentRow<T>(state: this, textStyle: textStyle),
          ),
          ...widget.trailing,
        ],
      ),
    );
  }
}

/// Pill track: rebuilds the sliding pill and segment colors per tick.
class _SegmentTrack extends StatelessWidget {
  const _SegmentTrack({
    required this.animation,
    required this.stackKey,
    required this.pillRect,
    required this.segments,
  });

  final Listenable animation;
  final GlobalKey stackKey;
  final Rect? Function() pillRect;
  final Widget Function() segments;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: albumPillFill,
        shape: StadiumBorder(side: BorderSide(color: albumSageLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AlbumSpace.xs),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final rect = pillRect();
            return Stack(
              key: stackKey,
              children: [
                if (rect != null)
                  Positioned.fromRect(
                    rect: rect,
                    child: const DecoratedBox(
                      key: Key('view-switch-pill'),
                      decoration: ShapeDecoration(
                        color: albumTerracotta,
                        shape: StadiumBorder(),
                      ),
                    ),
                  ),
                segments(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The segment labels, recolored from [state] on every animation tick.
class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({required this.state, required this.textStyle});

  final _ViewSwitchState<T> state;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final widget = state.widget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.values.length; i++)
          KeyedSubtree(
            key: state._keys[i],
            child: _Segment(
              tappableKey: widget.segmentKeyOf?.call(widget.values[i]),
              label: widget.labelOf(widget.values[i]),
              selected: widget.values[i] == widget.selected,
              style: textStyle?.copyWith(color: state._foreground(i)),
              onPress: () {
                final value = widget.values[i];
                if (value != widget.selected) widget.onChanged(value);
              },
            ),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.tappableKey,
    required this.label,
    required this.selected,
    required this.style,
    required this.onPress,
  });

  final Key? tappableKey;
  final String label;
  final bool selected;
  final TextStyle? style;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    // FTappable reports button + selected to semantics itself.
    return FTappable(
      key: tappableKey,
      selected: selected,
      onPress: onPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AlbumTarget.min),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlbumSpace.l),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
        ),
      ),
    );
  }
}

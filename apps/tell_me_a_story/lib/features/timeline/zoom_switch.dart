import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';

/// Terracotta segment that slides between Decades, Years, and Days.
///
/// Each zoom replaces the rail, so the last selection is remembered here
/// and the new switch slides from that segment.
class _ZoomSwitch extends StatefulWidget {
  const _ZoomSwitch({
    required this.selected,
    required this.onMacro,
    required this.onMid,
    required this.onFullCards,
  });

  final TimelineZoom selected;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  static TimelineZoom? _last;

  static int _indexOf(TimelineZoom zoom) {
    return switch (zoom) {
      TimelineZoom.far => 0,
      TimelineZoom.mid => 1,
      TimelineZoom.near => 2,
    };
  }

  @override
  State<_ZoomSwitch> createState() => _ZoomSwitchState();
}

class _ZoomSwitchState extends State<_ZoomSwitch>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _keys = List<GlobalKey>.generate(3, (_) => GlobalKey());
  late final AnimationController _controller;
  late int _fromIndex;
  late int _toIndex;
  Rect? _fromRect;
  Rect? _toRect;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _fromIndex = _ZoomSwitch._indexOf(_ZoomSwitch._last ?? widget.selected);
    _toIndex = _ZoomSwitch._indexOf(widget.selected);
    _ZoomSwitch._last = widget.selected;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didUpdateWidget(covariant _ZoomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    _fromIndex = _ZoomSwitch._indexOf(oldWidget.selected);
    _toIndex = _ZoomSwitch._indexOf(widget.selected);
    _ZoomSwitch._last = widget.selected;
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
    if (!mounted) return;
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

  Color _foreground(int index) {
    final dim = albumInk.withAlpha(0xB3);
    final t = _fromIndex == _toIndex
        ? 1.0
        : Curves.easeOutCubic.transform(_controller.value);
    if (index == _toIndex && index == _fromIndex) return albumParchment;
    if (index == _toIndex) return Color.lerp(dim, albumParchment, t)!;
    if (index == _fromIndex) return Color.lerp(albumParchment, dim, t)!;
    return dim;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
    final choices = [
      (
        key: 'timeline-zoom-macro',
        label: 'Decades',
        zoom: TimelineZoom.far,
        onPressed: widget.onMacro,
      ),
      (
        key: 'timeline-zoom-mid',
        label: 'Years',
        zoom: TimelineZoom.mid,
        onPressed: widget.onMid,
      ),
      (
        key: 'timeline-zoom-full',
        label: 'Days',
        zoom: TimelineZoom.near,
        onPressed: widget.onFullCards,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: albumInk.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _fromIndex == _toIndex
                ? 1.0
                : Curves.easeOutCubic.transform(_controller.value);
            final rect = _fromRect == null || _toRect == null
                ? null
                : Rect.lerp(_fromRect, _toRect, t);
            return Stack(
              key: _stackKey,
              children: [
                if (rect != null)
                  Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: const DecoratedBox(
                      key: Key('timeline-zoom-pill'),
                      decoration: ShapeDecoration(
                        color: albumTerracotta,
                        shape: StadiumBorder(),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < choices.length; i++)
                      KeyedSubtree(
                        key: _keys[i],
                        child: TextButton(
                          key: Key(choices[i].key),
                          onPressed: widget.selected == choices[i].zoom
                              ? () {}
                              : choices[i].onPressed,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: albumBackdropClear,
                            foregroundColor: _foreground(i),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(choices[i].label),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DialSubheader extends StatelessWidget {
  const DialSubheader({
    super.key,
    required this.selected,
    required this.onMacro,
    required this.onMid,
    required this.onFullCards,
  });

  final TimelineZoom selected;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 16,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _ZoomSwitch(
                  selected: selected,
                  onMacro: onMacro,
                  onMid: onMid,
                  onFullCards: onFullCards,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

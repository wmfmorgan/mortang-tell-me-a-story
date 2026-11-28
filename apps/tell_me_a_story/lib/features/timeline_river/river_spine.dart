import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import 'river_beat.dart';
import 'river_beat_tile.dart';
import 'river_density.dart';

/// The sage band, the spine, and the beats that snap to center.
class RiverSpine extends StatefulWidget {
  const RiverSpine({
    super.key,
    required this.beats,
    required this.density,
    required this.focusId,
    required this.photos,
    required this.onFocus,
    required this.onOpen,
    required this.onMove,
    required this.onEdge,
    required this.onDensity,
  });

  final List<RiverBeat> beats;
  final RiverDensity density;
  final String focusId;
  final PhotosGateway? photos;
  final ValueChanged<RiverBeat> onFocus;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final ValueChanged<bool> onEdge;
  final ValueChanged<int> onDensity;

  @override
  State<RiverSpine> createState() => _RiverSpineState();
}

class _RiverSpineState extends State<RiverSpine> {
  final _viewportKey = GlobalKey();
  final _keys = <String, GlobalKey>{};
  final _points = <int, Offset>{};
  var _lock = false;
  double? _pinchBase;

  @override
  void initState() {
    super.initState();
    _scheduleCenter();
  }

  @override
  void didUpdateWidget(covariant RiverSpine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusId != widget.focusId ||
        oldWidget.density != widget.density ||
        oldWidget.beats.length != widget.beats.length) {
      _scheduleCenter();
    }
  }

  void _scheduleCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_center());
    });
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  Future<void> _center() async {
    final current = _keys[widget.focusId]?.currentContext;
    if (current == null) return;
    _lock = true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    await Scrollable.ensureVisible(
      current,
      alignment: 0.5,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
    );
    _lock = false;
  }

  bool _onScroll(ScrollNotification note) {
    if (note is! ScrollEndNotification || _lock) return false;
    final index = _nearest();
    if (index == null) return false;
    final beat = widget.beats[index];
    if (beat.stories.any((story) => story.id == widget.focusId)) return false;
    widget.onFocus(beat);
    return false;
  }

  int? _nearest() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final center = viewport
        .localToGlobal(Offset(0, viewport.size.height / 2))
        .dy;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.beats.length; i++) {
      final box = _keys[widget.beats[i].id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final y = box.localToGlobal(Offset(0, box.size.height / 2)).dy;
      final dist = (y - center).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onMove(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onMove(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      widget.onEdge(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.onEdge(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      widget.onOpen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
      widget.onDensity(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      widget.onDensity(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _pointerDown(PointerDownEvent event) {
    _points[event.pointer] = event.position;
  }

  void _pointerUp(PointerEvent event) {
    _points.remove(event.pointer);
    if (_points.length < 2) _pinchBase = null;
  }

  void _pointerMove(PointerMoveEvent event) {
    _points[event.pointer] = event.position;
    if (_points.length < 2) return;
    final points = _points.values.toList();
    final distance = (points[0] - points[1]).distance;
    final base = _pinchBase;
    if (base == null) {
      _pinchBase = distance;
      return;
    }
    if (distance > base * 1.12) {
      _pinchBase = distance;
      widget.onDensity(1);
    } else if (distance < base * 0.88) {
      _pinchBase = distance;
      widget.onDensity(-1);
    }
  }

  void _pointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (!keys.isControlPressed && !keys.isMetaPressed) return;
    if (event.scrollDelta.dy > 0) widget.onDensity(-1);
    if (event.scrollDelta.dy < 0) widget.onDensity(1);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final focus = beatIndexFor(widget.beats, widget.focusId);
    return ColoredBox(
      key: _viewportKey,
      color: sageTint,
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: _pointerDown,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerUp,
          onPointerMove: _pointerMove,
          onPointerSignal: _pointerSignal,
          child: Stack(
            children: [
              const Positioned(
                left: 159,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 2,
                  child: ColoredBox(color: albumTerracotta),
                ),
              ),
              _list(focus, reduced),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(int focus, bool reduced) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: constraints.maxHeight / 2),
            child: Column(
              children: [
                for (var i = 0; i < widget.beats.length; i++)
                  _tile(i, focus, reduced),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(int index, int focus, bool reduced) {
    final beat = widget.beats[index];
    final previous = index == 0 ? null : widget.beats[index - 1].anchorYear;
    return KeyedSubtree(
      key: _keyFor(beat.id),
      child: RiverBeatTile(
        beat: beat,
        density: widget.density,
        focused: index == focus,
        distance: (index - focus).abs(),
        reducedMotion: reduced,
        showDecade: _newDecade(previous, beat.anchorYear),
        focusId: widget.focusId,
        photos: widget.photos,
        onTap: () => widget.onFocus(beat),
        onOpen: widget.onOpen,
      ),
    );
  }
}

bool _newDecade(int? previousYear, int year) {
  if (previousYear == null) return true;
  return decadeStartYearDate(previousYear) != decadeStartYearDate(year);
}

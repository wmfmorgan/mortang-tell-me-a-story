import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _wheelStepPx = 50.0;
const _pinchOut = 1.2;
const _pinchIn = 1 / 1.2;
const _cooldown = Duration(milliseconds: 300);
const _gestureGap = Duration(milliseconds: 120);

/// Claims pinch and Ctrl/⌘ + wheel over the thread and steps density once.
class ThreadPointerHandler extends StatefulWidget {
  const ThreadPointerHandler({
    super.key,
    required this.child,
    this.onDensityDelta,
    this.now,
  });

  final Widget child;

  /// Positive is finer, negative is coarser. Null still claims the gesture.
  final ValueChanged<int>? onDensityDelta;

  /// Gap and cooldown clock. Defaults to the last scheduler time stamp.
  final Duration Function()? now;

  @override
  State<ThreadPointerHandler> createState() => _ThreadPointerHandlerState();
}

class _ThreadPointerHandlerState extends State<ThreadPointerHandler> {
  var _zoom = const _Zoom();

  Duration _now() {
    final clock = widget.now;
    if (clock != null) return clock();
    return WidgetsBinding.instance.currentSystemFrameTimeStamp;
  }

  void _onSignal(PointerSignalEvent event) {
    final keys = HardwareKeyboard.instance;
    final applied = _apply(
      _zoom,
      event,
      at: _now(),
      controlOrMeta: keys.isControlPressed || keys.isMetaPressed,
    );
    _zoom = applied.zoom;
    if (!applied.claim) return;
    final step = applied.step;
    final onDensity = widget.onDensityDelta;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      event.respond(allowPlatformDefault: false);
      if (step != 0 && onDensity != null) onDensity(step);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _onSignal,
      child: widget.child,
    );
  }
}

class _Zoom {
  const _Zoom({
    this.wheel = 0,
    this.scale = 1,
    this.lastAt,
    this.steppedAt,
    this.latched = false,
  });

  final double wheel;
  final double scale;
  final Duration? lastAt;
  final Duration? steppedAt;
  final bool latched;
}

class _Applied {
  const _Applied({required this.zoom, this.claim = false, this.step = 0});

  final _Zoom zoom;
  final bool claim;
  final int step;
}

_Applied _apply(
  _Zoom zoom,
  PointerSignalEvent event, {
  required Duration at,
  required bool controlOrMeta,
}) {
  if (event is PointerScaleEvent) return _pinch(zoom, event, at);
  if (event is PointerScrollEvent && controlOrMeta)
    return _wheel(zoom, event, at);
  return _Applied(zoom: zoom);
}

_Applied _pinch(_Zoom zoom, PointerScaleEvent event, Duration at) {
  final scale = event.scale;
  if (!(scale > 0)) {
    return _Applied(zoom: _hold(zoom, at), claim: true);
  }
  return _advance(zoom, at, wheel: 0, scale: scale, pinch: true);
}

_Applied _wheel(_Zoom zoom, PointerScrollEvent event, Duration at) {
  final dy = event.scrollDelta.dy;
  if (dy == 0) return _Applied(zoom: zoom);
  return _advance(zoom, at, wheel: -dy, scale: 1, pinch: false);
}

_Zoom _hold(_Zoom zoom, Duration at) {
  return _Zoom(
    wheel: zoom.wheel,
    scale: zoom.scale,
    lastAt: at,
    steppedAt: zoom.steppedAt,
    latched: zoom.latched,
  );
}

_Applied _advance(
  _Zoom zoom,
  Duration at, {
  required double wheel,
  required double scale,
  required bool pinch,
}) {
  final previous = zoom.lastAt;
  final fresh = previous != null && at - previous > _gestureGap;
  final latched = fresh ? false : zoom.latched;
  final steppedAt = zoom.steppedAt;
  final cooled = steppedAt != null && at - steppedAt < _cooldown;
  if (latched || cooled) {
    return _Applied(
      zoom: _Zoom(lastAt: at, steppedAt: steppedAt, latched: latched),
      claim: true,
    );
  }
  final nextWheel = (fresh ? 0.0 : zoom.wheel) + wheel;
  final nextScale = (fresh ? 1.0 : zoom.scale) * scale;
  final step = pinch ? _scaleStep(nextScale) : _wheelStep(nextWheel);
  if (step == 0) {
    return _Applied(
      zoom: _Zoom(
        wheel: nextWheel,
        scale: nextScale,
        lastAt: at,
        steppedAt: steppedAt,
      ),
      claim: true,
    );
  }
  return _Applied(
    zoom: _Zoom(lastAt: at, steppedAt: at, latched: true),
    claim: true,
    step: step,
  );
}

int _wheelStep(double wheel) {
  if (wheel >= _wheelStepPx) return 1;
  if (wheel <= -_wheelStepPx) return -1;
  return 0;
}

int _scaleStep(double scale) {
  if (scale >= _pinchOut) return 1;
  if (scale <= _pinchIn) return -1;
  return 0;
}

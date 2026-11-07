import 'package:flutter/widgets.dart';

import '../theme/lab_theme.dart';
import 'playback_controller.dart';

/// Viewport fraction where camera follow keeps the playback cursor
/// (horizontal renderers).
const kFollowAt = 0.65;

/// Viewport fraction where vertical renderers put a focused story.
const kFocusAlignment = 0.4;

/// Scroll offset that puts content position [contentPx] at [fraction] of
/// the viewport, clamped to the scroll range.
double scrollOffsetToPlace(
  double contentPx,
  ScrollMetrics m,
  double fraction,
) => (contentPx - m.viewportDimension * fraction).clamp(0.0, m.maxScrollExtent);

/// The playback cursor line, the same in every renderer. [zoom] is the
/// canvas scale, so the stroke stays 2 screen px in a scaled canvas.
void paintPlaybackCursor(
  Canvas canvas,
  Offset from,
  Offset to, {
  double zoom = 1,
}) => canvas.drawLine(
  from,
  to,
  Paint()
    ..color = labTerracotta
    ..strokeWidth = 2 / zoom,
);

/// Fades [child] in as [playback] reveals [storyId]. Rebuilds only when this
/// story's own visibility changes, so thousands of cards cost one cheap
/// listener call per tick, not a rebuild. Hidden cards ignore pointers.
class RevealOpacity extends StatefulWidget {
  const RevealOpacity({
    super.key,
    required this.playback,
    required this.storyId,
    required this.child,
  });

  final PlaybackController? playback;
  final String storyId;
  final Widget child;

  @override
  State<RevealOpacity> createState() => _RevealOpacityState();
}

class _RevealOpacityState extends State<RevealOpacity> {
  double _value = 1;

  @override
  void initState() {
    super.initState();
    widget.playback?.addListener(_onTick);
    _value = widget.playback?.reveal(widget.storyId) ?? 1;
  }

  @override
  void didUpdateWidget(RevealOpacity old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback?.removeListener(_onTick);
      widget.playback?.addListener(_onTick);
    }
    _value = widget.playback?.reveal(widget.storyId) ?? 1;
  }

  void _onTick() {
    final v = widget.playback!.reveal(widget.storyId);
    if (v != _value) setState(() => _value = v);
  }

  @override
  void dispose() {
    widget.playback?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_value >= 1) return widget.child;
    return IgnorePointer(
      ignoring: _value == 0,
      child: Opacity(opacity: _value, child: widget.child),
    );
  }
}

/// Tracks the [BuildContext] of each currently built story so vertical
/// renderers can scroll the current playback story into view.
class StoryContextRegistry {
  final _contexts = <String, BuildContext>{};

  BuildContext? operator [](String storyId) => _contexts[storyId];
}

class RegisterStory extends StatefulWidget {
  const RegisterStory({
    super.key,
    required this.registry,
    required this.storyId,
    required this.child,
  });

  final StoryContextRegistry registry;
  final String storyId;
  final Widget child;

  @override
  State<RegisterStory> createState() => _RegisterStoryState();
}

class _RegisterStoryState extends State<RegisterStory> {
  @override
  void initState() {
    super.initState();
    widget.registry._contexts[widget.storyId] = context;
  }

  @override
  void didUpdateWidget(RegisterStory old) {
    super.didUpdateWidget(old);
    if (old.storyId != widget.storyId || old.registry != widget.registry) {
      _unregister(old);
      widget.registry._contexts[widget.storyId] = context;
    }
  }

  void _unregister(RegisterStory w) {
    if (identical(w.registry._contexts[w.storyId], context)) {
      w.registry._contexts.remove(w.storyId);
    }
  }

  @override
  void dispose() {
    _unregister(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps the current playback story in view for vertical, card-based
/// renderers. When the story's card isn't built (lazy lists), jumps to an
/// estimate from [estimateFraction] first and settles on the next frame.
class FollowCurrentStory {
  FollowCurrentStory({
    required this.playback,
    required this.registry,
    required this.scroll,
    required this.estimateFraction,
  }) {
    playback.addListener(_onPlayback);
  }

  final PlaybackController playback;
  final StoryContextRegistry registry;
  final ScrollController scroll;

  /// 0 = top of the scroll extent, 1 = bottom.
  final double Function(String storyId) estimateFraction;

  String? _lastId;

  void _onPlayback() {
    final current = playback.current;
    if (!playback.active || !playback.follow || current == null) {
      _lastId = null;
      return;
    }
    if (current.id == _lastId) return;
    _lastId = current.id;
    _reveal(current.id, retry: true);
  }

  void _reveal(String id, {required bool retry}) {
    final ctx = registry[id];
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: kFocusAlignment,
        duration: playback.reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
      return;
    }
    if (!retry || !scroll.hasClients) return;
    final p = scroll.position;
    scroll.jumpTo(estimateFraction(id).clamp(0, 1) * p.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastId == id) _reveal(id, retry: false);
    });
  }

  void dispose() => playback.removeListener(_onPlayback);
}

/// Turns camera follow off when the user starts dragging a scrollable.
bool disableFollowOnUserScroll(
  ScrollStartNotification n,
  PlaybackController? playback,
) {
  if (n.dragDetails != null && playback != null && playback.active) {
    playback.setFollow(false);
  }
  return false;
}

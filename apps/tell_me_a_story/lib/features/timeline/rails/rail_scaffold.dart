import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';
import 'package:tell_me_a_story/features/timeline/zoom_switch.dart';

/// Opacity and distance from the viewport centre of one measured row.
typedef RowFade = ({double opacity, double distance});

/// Edge-band fade shared by Decades and Days: [opacity] is
/// [farEdgeOpacity] or [fullCardOpacity].
RowFade Function(RenderBox row) edgeFade(
  RenderBox viewport,
  double Function({
    required double rowTop,
    required double rowHeight,
    required double viewportTop,
    required double viewportHeight,
  })
  opacity,
) {
  final viewportTop = viewport.localToGlobal(Offset.zero).dy;
  final viewportHeight = viewport.size.height;
  final centerY = viewportTop + viewportHeight / 2;
  return (row) {
    final rowTop = row.localToGlobal(Offset.zero).dy;
    return (
      opacity: opacity(
        rowTop: rowTop,
        rowHeight: row.size.height,
        viewportTop: viewportTop,
        viewportHeight: viewportHeight,
      ),
      distance: (rowTop + row.size.height / 2 - centerY).abs(),
    );
  };
}

/// Shared state of the three rails: one row per key [K] (a decade's start
/// year, or a story id). It centres the focused row on the first frame,
/// re-measures on scroll, tracks the row nearest the viewport centre and
/// reports its story through [onCenterStory], steps rows with the arrow
/// keys, and keeps each row's fade opacity.
mixin RailScaffold<W extends StatefulWidget, K> on State<W> {
  /// The [Stack] that [measure] treats as the viewport.
  final viewportKey = GlobalKey();
  final scroll = ScrollController();

  /// Row nearest the viewport centre.
  K? centerKey;

  /// Measured fade per row; unmeasured rows use [opacityOf]'s fallback.
  Map<K, double> opacities = const {};

  /// Row keys in rail order.
  Iterable<K> get rowKeys;

  /// Context of the row widget for [key], if built.
  BuildContext? rowContext(K key);

  /// Row centred on the first frame.
  K? get initialCenterKey;

  /// Row centred on the first frame when [initialCenterKey] is null.
  K? get fallbackCenterKey => null;

  /// Row the arrow keys step from when nothing is centred yet.
  K? get stepFallbackKey => fallbackCenterKey;

  /// Measure after the first frame even when no row was centred.
  bool get measureWithoutTarget => false;

  /// Opacity change below which a re-measure skips its rebuild.
  double get opacityTolerance;

  /// Per-row fade for this pass; [viewport] is read once.
  RowFade Function(RenderBox row) fadeFor(RenderBox viewport);

  /// Story to focus when [key] becomes the centre row.
  String? focusIdFor(K key);

  String? get focusedStoryId;

  void onCenterStory(String id);

  @override
  void initState() {
    super.initState();
    centerKey = initialCenterKey;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  /// Fade of [key]: measured, else 1 at the centre and [unmeasured] elsewhere.
  double opacityOf(K key, {required double unmeasured}) {
    return opacities[key] ?? (key == centerKey ? 1 : unmeasured);
  }

  void _centerInitial() {
    if (!mounted) return;
    final key = centerKey ?? fallbackCenterKey;
    if (key != null) centerKey = key;
    centerOn(key);
  }

  /// Scrolls [key] to the centre at once, then measures.
  void centerOn(K? key) {
    final target = key == null ? null : rowContext(key);
    if (target != null && target.mounted) {
      Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    } else if (!measureWithoutTarget) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) measure();
    });
  }

  /// Centres [next] when the focus moved to a row that is not centred.
  void followFocus(K? next, K? previous) {
    if (next != null && next != previous && next != centerKey) {
      centerKey = next;
      centerOn(next);
    }
  }

  void step(int direction) {
    final keys = rowKeys.toList();
    if (keys.isEmpty) return;
    final current = centerKey ?? stepFallbackKey;
    var index = keys.indexWhere((key) => key == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= keys.length
        ? null
        : rowContext(keys[next]);
    scrollDialStep(controller: scroll, direction: direction, target: target);
  }

  void measure() {
    if (!mounted) return;
    final viewport =
        viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final fade = fadeFor(viewport);
    K? bestKey;
    var best = double.infinity;
    final next = <K, double>{};
    for (final key in rowKeys) {
      final row = rowContext(key)?.findRenderObject() as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final (:opacity, :distance) = fade(row);
      next[key] = opacity;
      if (distance < best) {
        best = distance;
        bestKey = key;
      }
    }
    final keyChanged = bestKey != null && bestKey != centerKey;
    if (!keyChanged && _sameOpacity(next)) return;
    setState(() {
      if (bestKey != null) centerKey = bestKey;
      opacities = next;
    });
    if (!keyChanged) return;
    final id = focusIdFor(bestKey as K);
    if (id != null && id != focusedStoryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != focusedStoryId) onCenterStory(id);
      });
    }
  }

  bool _sameOpacity(Map<K, double> next) {
    if (next.length != opacities.length) return false;
    for (final entry in next.entries) {
      final previous = opacities[entry.key];
      if (previous == null ||
          (previous - entry.value).abs() > opacityTolerance) {
        return false;
      }
    }
    return true;
  }

  /// Zoom switch above an arrow-key, empty-tap rail. [viewport] holds the
  /// [Stack] keyed [viewportKey]; scrolling re-measures. [action] sits
  /// beside the zoom switch. [notice] is pinned between the zoom switch and
  /// the rows, so it never covers a row (the C17 no-match card).
  Widget buildRail({
    required TimelineZoom selected,
    required VoidCallback onMacro,
    required VoidCallback onMid,
    required VoidCallback onFullCards,
    required VoidCallback onEmpty,
    required Widget viewport,
    Widget? action,
    Widget? notice,
  }) {
    return _ArrowKeys(
      onStep: step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: DialSubheader(
              selected: selected,
              onMacro: onMacro,
              onMid: onMid,
              onFullCards: onFullCards,
              action: action,
            ),
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: notice,
            ),
          Expanded(
            child: _EmptyTap(
              onTap: onEmpty,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollEndNotification) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) measure();
                    });
                  }
                  return false;
                },
                child: viewport,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void scrollDialStep({
  required ScrollController controller,
  required int direction,
  required BuildContext? target,
}) {
  if (target != null && target.mounted) {
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return;
  }
  if (!controller.hasClients) return;
  final position = controller.position;
  final delta = direction * position.viewportDimension * 0.45;
  final next = (position.pixels + delta).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  position.animateTo(
    next,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );
}

class _ArrowKeys extends StatefulWidget {
  const _ArrowKeys({required this.onStep, required this.child});

  final ValueChanged<int> onStep;
  final Widget child;

  @override
  State<_ArrowKeys> createState() => _ArrowKeysState();
}

class _ArrowKeysState extends State<_ArrowKeys> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onStep(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onStep(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: (_) => _focus.requestFocus(),
        child: widget.child,
      ),
    );
  }
}

/// Small empty target at the top-left of a rail. Interactive children stay above it.
class _EmptyTap extends StatelessWidget {
  const _EmptyTap({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          child: GestureDetector(
            key: const Key('timeline-empty'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox(width: 48, height: 24),
          ),
        ),
      ],
    );
  }
}

class HangParentParentData extends ContainerBoxParentData<RenderBox> {}

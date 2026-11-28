import 'dart:async';

import 'package:flutter/widgets.dart';

import 'thread_center.dart';

enum _SnapPhase { idle, dragging, snapping }

class ThreadFocusController {
  ThreadFocusController({required this.scroll, required this.onSettled});

  final ScrollController scroll;
  final void Function(String storyId) onSettled;
  var _phase = _SnapPhase.idle;
  var _generation = 0;
  var _applying = false;

  /// Jumps the list without treating the scroll-end as a user release.
  ///
  /// [ScrollController.jumpTo] emits a scroll end. Snapping from that end
  /// starts an animate, and that animate leaves the scrollable ignoring
  /// pointers after the jump replaces the activity. The generation bump
  /// drops an in-flight snap or drag so its completion cannot settle.
  void place(double offset) {
    _generation += 1;
    _phase = _SnapPhase.idle;
    if (!scroll.hasClients) return;
    _applying = true;
    try {
      scroll.jumpTo(offset);
    } finally {
      _applying = false;
    }
  }

  void onNotification({
    required ScrollNotification notification,
    required List<double> extents,
    required List<double> offsets,
    required double viewport,
    required bool reducedMotion,
    required bool Function(int index) eligible,
    required void Function(int index) onMove,
  }) {
    if (_applying || notification.depth != 0) return;
    final drag = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails,
      ScrollUpdateNotification(:final dragDetails) => dragDetails,
      ScrollEndNotification(:final dragDetails) => dragDetails,
      _ => null,
    };
    final moved =
        notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification;
    if (moved && drag != null) {
      _phase = _SnapPhase.dragging;
      _generation += 1;
      return;
    }
    if (moved && _phase == _SnapPhase.dragging) {
      _phase = _SnapPhase.idle;
      return;
    }
    if (notification is! ScrollEndNotification) return;
    if (drag != null) {
      _release(extents, offsets, viewport, eligible, onMove, reducedMotion);
      return;
    }
    if (_phase == _SnapPhase.dragging || _phase == _SnapPhase.snapping) {
      return;
    }
    _snap(extents, offsets, viewport, eligible, onMove);
  }

  void moveToOffset({
    required double offset,
    required String storyId,
    required String? focusId,
    required bool reducedMotion,
  }) {
    if (_phase == _SnapPhase.dragging) return;
    _moveTo(offset, storyId, focusId, reducedMotion);
  }

  void _release(
    List<double> extents,
    List<double> offsets,
    double viewport,
    bool Function(int index) eligible,
    void Function(int index) onMove,
    bool reducedMotion,
  ) {
    _phase = _SnapPhase.idle;
    if (reducedMotion) {
      _snap(extents, offsets, viewport, eligible, onMove);
      return;
    }
    final generation = _generation;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation || _phase == _SnapPhase.dragging) return;
      if (!scroll.hasClients || scroll.position.isScrollingNotifier.value) {
        return;
      }
      _snap(extents, offsets, viewport, eligible, onMove);
    });
  }

  void _snap(
    List<double> extents,
    List<double> offsets,
    double viewport,
    bool Function(int index) eligible,
    void Function(int index) onMove,
  ) {
    if (_phase == _SnapPhase.dragging || extents.isEmpty) return;
    onMove(
      ThreadCenter.nearestRow(
        offset: scroll.hasClients ? scroll.offset : 0,
        extents: extents,
        offsets: offsets,
        viewport: viewport,
        eligible: eligible,
      ),
    );
  }

  void _moveTo(
    double target,
    String storyId,
    String? focusId,
    bool reducedMotion,
  ) {
    if (!scroll.hasClients) return;
    final generation = ++_generation;
    if ((scroll.offset - target).abs() < 0.5) {
      _settle(storyId, focusId, generation);
      return;
    }
    _phase = _SnapPhase.snapping;
    if (reducedMotion) {
      place(target);
      _settle(storyId, focusId, _generation);
      return;
    }
    scroll
        .animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
          scheduleMicrotask(() => _settle(storyId, focusId, generation));
        });
  }

  void _settle(String storyId, String? focusId, int generation) {
    if (generation != _generation || _phase == _SnapPhase.dragging) return;
    _phase = _SnapPhase.idle;
    if (storyId != focusId) onSettled(storyId);
  }
}

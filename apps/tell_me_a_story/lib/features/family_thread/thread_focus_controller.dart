import 'dart:async';

import 'package:flutter/widgets.dart';

import 'thread_beat.dart';
import 'thread_center.dart';
import 'thread_focus.dart';

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
  /// pointers after the jump replaces the activity.
  void place(double offset) {
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
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
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
      _release(
        beats: beats,
        extent: extent,
        viewport: viewport,
        focusId: focusId,
        reducedMotion: reducedMotion,
      );
      return;
    }
    if (_phase == _SnapPhase.dragging || _phase == _SnapPhase.snapping) {
      return;
    }
    _snap(
      beats: beats,
      extent: extent,
      viewport: viewport,
      focusId: focusId,
      reducedMotion: reducedMotion,
    );
  }

  void _release({
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
  }) {
    _phase = _SnapPhase.idle;
    if (reducedMotion) {
      _snap(
        beats: beats,
        extent: extent,
        viewport: viewport,
        focusId: focusId,
        reducedMotion: reducedMotion,
      );
      return;
    }
    final generation = _generation;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation || _phase == _SnapPhase.dragging) return;
      if (!scroll.hasClients || scroll.position.isScrollingNotifier.value) {
        return;
      }
      _snap(
        beats: beats,
        extent: extent,
        viewport: viewport,
        focusId: focusId,
        reducedMotion: reducedMotion,
      );
    });
  }

  void _snap({
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
  }) {
    if (_phase == _SnapPhase.dragging) return;
    moveToBeat(
      index: ThreadCenter.nearestIndex(
        scroll.hasClients ? scroll.offset : 0,
        beats.length,
        viewport,
        extent,
      ),
      beats: beats,
      extent: extent,
      viewport: viewport,
      focusId: focusId,
      reducedMotion: reducedMotion,
    );
  }

  void moveToBeat({
    required int index,
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
  }) {
    if (!scroll.hasClients || beats.isEmpty || viewport <= 0 || extent <= 0) {
      return;
    }
    final clamped = index.clamp(0, beats.length - 1).toInt();
    _moveTo(
      ThreadCenter.centerOffset(clamped, beats.length, viewport, extent),
      ThreadFocus.representative(beats[clamped], previousFocusId: focusId).id,
      focusId,
      reducedMotion,
    );
  }

  void _moveTo(
    double target,
    String storyId,
    String? focusId,
    bool reducedMotion,
  ) {
    final generation = ++_generation;
    if ((scroll.offset - target).abs() < 0.5) {
      _settle(storyId, focusId, generation);
      return;
    }
    _phase = _SnapPhase.snapping;
    if (reducedMotion) {
      _applying = true;
      try {
        scroll.jumpTo(target);
      } finally {
        _applying = false;
      }
      _settle(storyId, focusId, generation);
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

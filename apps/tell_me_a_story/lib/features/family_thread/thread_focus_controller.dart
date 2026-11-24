import 'dart:async';

import 'package:flutter/widgets.dart';

import 'thread_beat.dart';
import 'thread_center.dart';
import 'thread_filter.dart';
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
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
    ThreadFilter filter = ThreadFilter.cleared,
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
        filter: filter,
      );
      return;
    }
    if (_phase == _SnapPhase.dragging || _phase == _SnapPhase.snapping) return;
    _snap(
      beats: beats,
      extent: extent,
      viewport: viewport,
      focusId: focusId,
      reducedMotion: reducedMotion,
      filter: filter,
    );
  }

  void _release({
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
    required ThreadFilter filter,
  }) {
    _phase = _SnapPhase.idle;
    if (reducedMotion) {
      _snap(
        beats: beats,
        extent: extent,
        viewport: viewport,
        focusId: focusId,
        reducedMotion: reducedMotion,
        filter: filter,
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
        filter: filter,
      );
    });
  }

  void _snap({
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
    required ThreadFilter filter,
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
      filter: filter,
    );
  }

  void moveToBeat({
    required int index,
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
    ThreadFilter filter = ThreadFilter.cleared,
  }) {
    if (!scroll.hasClients || beats.isEmpty || viewport <= 0 || extent <= 0) {
      return;
    }
    final landed = _landOn(index, beats, filter);
    _moveTo(
      ThreadCenter.centerOffset(landed, beats.length, viewport, extent),
      ThreadFocus.representative(
        beats[landed],
        previousFocusId: focusId,
        filter: filter,
      ).id,
      focusId,
      reducedMotion,
    );
  }

  int _landOn(int index, List<ThreadBeat> beats, ThreadFilter filter) {
    final clamped = index.clamp(0, beats.length - 1).toInt();
    if (filter.matchesBeat(beats[clamped])) return clamped;
    for (var distance = 1; distance < beats.length; distance++) {
      final later = clamped + distance;
      final earlier = clamped - distance;
      if (later < beats.length && filter.matchesBeat(beats[later])) {
        return later;
      }
      if (earlier >= 0 && filter.matchesBeat(beats[earlier])) return earlier;
    }
    return clamped;
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

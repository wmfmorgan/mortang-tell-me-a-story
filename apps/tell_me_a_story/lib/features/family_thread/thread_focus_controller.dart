import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'thread_beat.dart';
import 'thread_focus.dart';

enum _SnapPhase { idle, dragging, snapping }

class ThreadFocusController {
  ThreadFocusController({required this.scroll, required this.onSettled});

  final ScrollController scroll;
  final void Function(String storyId) onSettled;
  var _phase = _SnapPhase.idle;
  var _generation = 0;

  void onNotification({
    required ScrollNotification notification,
    required List<ThreadBeat> beats,
    required double extent,
    required double viewport,
    required String? focusId,
    required bool reducedMotion,
  }) {
    if (notification.depth != 0) return;
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
      _release(beats, extent, viewport, focusId, reducedMotion);
      return;
    }
    if (_phase == _SnapPhase.dragging || _phase == _SnapPhase.snapping) {
      return;
    }
    _snap(beats, extent, viewport, focusId, reducedMotion);
  }

  void _release(
    List<ThreadBeat> beats,
    double extent,
    double viewport,
    String? focusId,
    bool reducedMotion,
  ) {
    _phase = _SnapPhase.idle;
    final generation = _generation;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation || _phase == _SnapPhase.dragging) return;
      if (!scroll.hasClients || scroll.position.isScrollingNotifier.value) {
        return;
      }
      _snap(beats, extent, viewport, focusId, reducedMotion);
    });
  }

  void _snap(
    List<ThreadBeat> beats,
    double extent,
    double viewport,
    String? focusId,
    bool reducedMotion,
  ) {
    if (_phase == _SnapPhase.dragging || !scroll.hasClients) return;
    if (beats.isEmpty || viewport <= 0 || extent <= 0) return;
    final index = _nearest(beats.length, extent, viewport);
    final target = _centered(index, beats.length, extent, viewport);
    final storyId = ThreadFocus.representative(
      beats[index],
      previousFocusId: focusId,
    ).id;
    final generation = ++_generation;
    if ((scroll.offset - target).abs() < 0.5) {
      _settle(storyId, focusId, generation);
      return;
    }
    _phase = _SnapPhase.snapping;
    if (reducedMotion) {
      scroll.jumpTo(target);
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

  int _nearest(int count, double extent, double viewport) {
    final pad = _pad(viewport, extent);
    final center = scroll.offset + viewport / 2;
    final index = ((center - pad - extent / 2) / extent).round();
    if (index < 0) return 0;
    if (index >= count) return count - 1;
    return index;
  }

  double _centered(int index, int count, double extent, double viewport) {
    final pad = _pad(viewport, extent);
    final raw = pad + index * extent + extent / 2 - viewport / 2;
    final maxScroll = math.max(0.0, pad * 2 + count * extent - viewport);
    final centered = raw.clamp(0.0, maxScroll);
    return centered.clamp(0.0, scroll.position.maxScrollExtent);
  }
}

double _pad(double viewport, double extent) {
  return ((viewport - extent) / 2).clamp(0.0, double.infinity);
}

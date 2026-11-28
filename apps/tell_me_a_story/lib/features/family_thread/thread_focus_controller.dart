import 'dart:async';

import 'package:flutter/widgets.dart';

enum _SnapPhase { idle, dragging, snapping }

class ThreadFocusController {
  ThreadFocusController({required this.scroll});

  final ScrollController scroll;
  var _phase = _SnapPhase.idle;
  var _generation = 0;
  var _applying = false;
  var _userMoved = false;

  /// Jumps the list without treating the scroll-end as a user release.
  void place(double offset) {
    _generation += 1;
    _phase = _SnapPhase.idle;
    _userMoved = false;
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
    required bool reducedMotion,
    required void Function() snap,
  }) {
    if (_applying || notification.depth != 0) return;
    final drag = _dragOf(notification);
    final moved =
        notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification;
    if (moved && drag != null) {
      _phase = _SnapPhase.dragging;
      _userMoved = true;
      _generation += 1;
      return;
    }
    if (moved && _phase == _SnapPhase.dragging) {
      _phase = _SnapPhase.idle;
      return;
    }
    if (notification is! ScrollEndNotification || !_userMoved) return;
    if (drag != null) {
      _release(reducedMotion: reducedMotion, snap: snap);
      return;
    }
    if (_phase == _SnapPhase.dragging || _phase == _SnapPhase.snapping) {
      return;
    }
    _userMoved = false;
    snap();
  }

  void _release({required bool reducedMotion, required void Function() snap}) {
    _phase = _SnapPhase.idle;
    if (reducedMotion) {
      _userMoved = false;
      snap();
      return;
    }
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation || _phase == _SnapPhase.dragging) return;
      if (!scroll.hasClients || scroll.position.isScrollingNotifier.value) {
        return;
      }
      _userMoved = false;
      snap();
    });
  }

  /// Centres [target] in the viewport. Does not move the anchor sliver.
  Future<void> reveal(BuildContext target, {required bool reducedMotion}) {
    if (!target.mounted) return Future<void>.value();
    final generation = ++_generation;
    _phase = _SnapPhase.snapping;
    _userMoved = false;
    _applying = true;
    final motion = Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    _applying = false;
    return motion.whenComplete(() {
      if (generation != _generation || _phase == _SnapPhase.dragging) return;
      _phase = _SnapPhase.idle;
    });
  }
}

Object? _dragOf(ScrollNotification notification) {
  return switch (notification) {
    ScrollStartNotification(:final dragDetails) => dragDetails,
    ScrollUpdateNotification(:final dragDetails) => dragDetails,
    ScrollEndNotification(:final dragDetails) => dragDetails,
    _ => null,
  };
}

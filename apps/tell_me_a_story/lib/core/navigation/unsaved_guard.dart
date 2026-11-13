import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'leave_story_dialog.dart';

/// Page-owned unsaved-input guard. The page supplies dirty, save, and discard.
class UnsavedGuard extends ChangeNotifier {
  UnsavedGuard({
    required this.exitPrompts,
    required this.isDirty,
    required this.save,
    required this.discard,
  });

  final bool exitPrompts;
  final bool Function() isDirty;
  final Future<bool> Function() save;
  final void Function() discard;

  bool _promptOpen = false;
  bool _skipNext = false;

  /// Notifies listeners after a setState that can change [isDirty].
  void changed() {
    if (hasListeners) notifyListeners();
  }

  /// The next [confirmLeave] proceeds once, with no dialog.
  void skipNextPrompt() {
    _skipNext = true;
  }

  /// True when the caller may leave. A second call while the prompt is open
  /// stays, so two exits cannot stack two dialogs.
  Future<bool> confirmLeave(
    BuildContext context, {
    String? switchToFamilyName,
  }) async {
    if (_promptOpen) return false;
    if (_skipNext) {
      _skipNext = false;
      return true;
    }
    if (!isDirty()) return true;
    _promptOpen = true;
    try {
      return await showLeaveStoryDialog(
        context,
        switchToFamilyName: switchToFamilyName,
        save: save,
        discard: discard,
      );
    } finally {
      _promptOpen = false;
    }
  }
}

/// Exposes the page guard to the header inside the scaffold.
class UnsavedGuardScope extends InheritedNotifier<UnsavedGuard> {
  const UnsavedGuardScope({
    required UnsavedGuard guard,
    required super.child,
    super.key,
  }) : super(notifier: guard);

  static UnsavedGuard? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UnsavedGuardScope>()
        ?.notifier;
  }
}

/// Story-route guards, keyed by the route [GoRouterState.pageKey].
abstract final class UnsavedGuards {
  static final Map<ValueKey<String>, UnsavedGuard> _byPage = {};

  static void register(ValueKey<String> pageKey, UnsavedGuard guard) {
    _byPage[pageKey] = guard;
  }

  static void unregister(ValueKey<String> pageKey, UnsavedGuard guard) {
    if (_byPage[pageKey] == guard) _byPage.remove(pageKey);
  }

  static Future<bool> onExit(BuildContext context, GoRouterState state) {
    final guard = _byPage[state.pageKey];
    if (guard == null) return Future<bool>.value(true);
    return guard.confirmLeave(context);
  }

  /// True when a story page (not settings or rename) still has unsaved input.
  static bool get anyExitDirty {
    for (final guard in _byPage.values) {
      if (guard.exitPrompts && guard.isDirty()) return true;
    }
    return false;
  }
}

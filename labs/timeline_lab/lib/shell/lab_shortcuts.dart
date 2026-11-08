import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class StepIntent extends Intent {
  const StepIntent(this.delta);

  final int delta;
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ClearSelectionIntent extends Intent {
  const ClearSelectionIntent();
}

/// Magic Keyboard and desktop keys. Text fields already swallow Space and
/// the arrows (`DefaultTextEditingShortcuts`), so typing never triggers these.
const labShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft): StepIntent(-1),
  SingleActivator(LogicalKeyboardKey.arrowRight): StepIntent(1),
  SingleActivator(LogicalKeyboardKey.keyF, meta: true): FocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.keyF, control: true): FocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.escape): ClearSelectionIntent(),
};

/// An action that claims its key only while [enabled] holds. When it is
/// disabled, `Shortcuts` ignores the key and it reaches the focused widget,
/// so a focused chip still toggles on Space.
class GuardedAction<T extends Intent> extends Action<T> {
  GuardedAction({required this.enabled, required this.onInvoke});

  final bool Function() enabled;
  final void Function(T intent) onInvoke;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    onInvoke(intent);
    return null;
  }
}

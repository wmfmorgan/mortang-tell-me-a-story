import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ThreadKeyboard extends StatefulWidget {
  const ThreadKeyboard({
    super.key,
    required this.onBeatDelta,
    required this.onFirst,
    required this.onLast,
    required this.child,
    this.onDensityDelta,
    this.onDrill,
    this.focusRequest = 0,
  });

  final ValueChanged<int> onBeatDelta;
  final VoidCallback onFirst;
  final VoidCallback onLast;
  final ValueChanged<int>? onDensityDelta;
  final VoidCallback? onDrill;
  final int focusRequest;
  final Widget child;

  @override
  State<ThreadKeyboard> createState() => _ThreadKeyboardState();
}

class _ThreadKeyboardState extends State<ThreadKeyboard> {
  final _focus = FocusNode();

  @override
  void didUpdateWidget(ThreadKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusRequest == oldWidget.focusRequest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final action = _keyAction(
      key: event.logicalKey,
      controlOrMeta: keys.isControlPressed || keys.isMetaPressed,
    );
    if (action == null || !_run(action)) return KeyEventResult.ignored;
    return KeyEventResult.handled;
  }

  bool _run(_KeyAction action) {
    switch (action) {
      case _KeyAction.previous:
        widget.onBeatDelta(-1);
        return true;
      case _KeyAction.next:
        widget.onBeatDelta(1);
        return true;
      case _KeyAction.first:
        widget.onFirst();
        return true;
      case _KeyAction.last:
        widget.onLast();
        return true;
      case _KeyAction.finer:
      case _KeyAction.coarser:
        final onDensity = widget.onDensityDelta;
        if (onDensity == null) return false;
        onDensity(action == _KeyAction.finer ? 1 : -1);
        return true;
      case _KeyAction.drill:
        final onDrill = widget.onDrill;
        if (onDrill == null) return false;
        onDrill();
        return true;
    }
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

enum _KeyAction { previous, next, first, last, finer, coarser, drill }

final _zoomKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.add,
  LogicalKeyboardKey.equal,
  LogicalKeyboardKey.minus,
  LogicalKeyboardKey.numpadAdd,
  LogicalKeyboardKey.numpadSubtract,
  // Spec: never Ctrl/Cmd 0.
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.numpad0,
};

final _actions = <LogicalKeyboardKey, _KeyAction>{
  LogicalKeyboardKey.arrowUp: _KeyAction.previous,
  LogicalKeyboardKey.arrowDown: _KeyAction.next,
  LogicalKeyboardKey.home: _KeyAction.first,
  LogicalKeyboardKey.end: _KeyAction.last,
  LogicalKeyboardKey.equal: _KeyAction.finer,
  LogicalKeyboardKey.add: _KeyAction.finer,
  LogicalKeyboardKey.numpadAdd: _KeyAction.finer,
  LogicalKeyboardKey.minus: _KeyAction.coarser,
  LogicalKeyboardKey.numpadSubtract: _KeyAction.coarser,
  LogicalKeyboardKey.enter: _KeyAction.drill,
  LogicalKeyboardKey.numpadEnter: _KeyAction.drill,
  LogicalKeyboardKey.space: _KeyAction.drill,
};

_KeyAction? _keyAction({
  required LogicalKeyboardKey key,
  required bool controlOrMeta,
}) {
  if (controlOrMeta && _zoomKeys.contains(key)) return null;
  return _actions[key];
}

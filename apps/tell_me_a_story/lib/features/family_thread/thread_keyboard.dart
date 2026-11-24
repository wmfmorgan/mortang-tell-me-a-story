import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ThreadKeyboard extends StatefulWidget {
  const ThreadKeyboard({
    super.key,
    required this.onBeat,
    required this.beatCount,
    required this.currentIndex,
    required this.matches,
    required this.child,
    this.onDensityDelta,
    this.onDrill,
    this.focusRequest = 0,
  });

  final ValueChanged<int> onBeat;
  final int beatCount;
  final int Function() currentIndex;
  final bool Function(int index) matches;
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
        return _go(_step(widget.currentIndex(), -1));
      case _KeyAction.next:
        return _go(_step(widget.currentIndex(), 1));
      case _KeyAction.first:
        return _go(_step(-1, 1));
      case _KeyAction.last:
        return _go(_step(widget.beatCount, -1));
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

  bool _go(int? index) {
    if (index == null) return true;
    widget.onBeat(index);
    return true;
  }

  int? _step(int from, int delta) {
    var index = from + delta;
    while (index >= 0 && index < widget.beatCount) {
      if (widget.matches(index)) return index;
      index += delta;
    }
    return null;
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

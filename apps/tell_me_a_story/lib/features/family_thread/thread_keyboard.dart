import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ThreadKeyboard extends StatefulWidget {
  const ThreadKeyboard({
    super.key,
    required this.onBeatDelta,
    required this.onBeatEdge,
    required this.child,
    this.onDensityDelta,
  });

  final ValueChanged<int> onBeatDelta;
  final ValueChanged<int> onBeatEdge;
  final ValueChanged<int>? onDensityDelta;
  final Widget child;

  @override
  State<ThreadKeyboard> createState() => _ThreadKeyboardState();
}

class _ThreadKeyboardState extends State<ThreadKeyboard> {
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
    final keys = HardwareKeyboard.instance;
    final action = _keyAction(
      key: event.logicalKey,
      controlOrMeta: keys.isControlPressed || keys.isMetaPressed,
      textField: _textFieldFocused(),
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
        widget.onBeatEdge(0);
        return true;
      case _KeyAction.last:
        widget.onBeatEdge(1);
        return true;
      case _KeyAction.finer:
      case _KeyAction.coarser:
        final onDensity = widget.onDensityDelta;
        if (onDensity == null) return false;
        onDensity(action == _KeyAction.finer ? 1 : -1);
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      descendantsAreFocusable: false,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: (_) => _focus.requestFocus(),
        child: widget.child,
      ),
    );
  }
}

enum _KeyAction { previous, next, first, last, finer, coarser }

final _zoomKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.add,
  LogicalKeyboardKey.equal,
  LogicalKeyboardKey.minus,
  LogicalKeyboardKey.numpadAdd,
  LogicalKeyboardKey.numpadSubtract,
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
};

_KeyAction? _keyAction({
  required LogicalKeyboardKey key,
  required bool controlOrMeta,
  required bool textField,
}) {
  if (textField) return null;
  if (controlOrMeta && _zoomKeys.contains(key)) return null;
  return _actions[key];
}

bool _textFieldFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorStateOfType<EditableTextState>() != null;
}

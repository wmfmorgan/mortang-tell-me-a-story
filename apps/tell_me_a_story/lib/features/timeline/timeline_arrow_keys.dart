import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void scrollDialStep({
  required ScrollController controller,
  required int direction,
  required BuildContext? target,
}) {
  if (target != null && target.mounted) {
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return;
  }
  if (!controller.hasClients) return;
  final position = controller.position;
  final delta = direction * position.viewportDimension * 0.45;
  final next = (position.pixels + delta).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  position.animateTo(
    next,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );
}

class ArrowKeys extends StatefulWidget {
  const ArrowKeys({super.key, required this.onStep, required this.child});

  final ValueChanged<int> onStep;
  final Widget child;

  @override
  State<ArrowKeys> createState() => _ArrowKeysState();
}

class _ArrowKeysState extends State<ArrowKeys> {
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
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onStep(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onStep(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

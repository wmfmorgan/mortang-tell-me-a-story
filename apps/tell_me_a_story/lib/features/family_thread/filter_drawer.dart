import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import 'family_thread_copy.dart';

class FilterDrawer extends StatefulWidget {
  const FilterDrawer({
    super.key,
    required this.child,
    required this.matched,
    required this.onClose,
  });

  final Widget child;
  final int matched;
  final VoidCallback onClose;

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    widget.onClose();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _scrim(),
        Align(alignment: Alignment.bottomCenter, child: _sheet(context)),
      ],
    );
  }

  Widget _scrim() {
    return Positioned.fill(
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.onClose,
          child: const ColoredBox(color: albumModalScrim),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return Material(
      color: albumParchment,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          children: [
            Expanded(child: widget.child),
            TextButton(
              onPressed: widget.onClose,
              child: Text(FamilyThreadCopy.showStories(widget.matched)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import 'family_thread_copy.dart';

class FilterDrawer extends StatefulWidget {
  const FilterDrawer({
    super.key,
    required this.child,
    required this.matched,
    required this.heightFactor,
    required this.onClose,
  });

  final Widget child;
  final int matched;
  final double heightFactor;
  final VoidCallback onClose;

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'filter-drawer');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSheet());
  }

  void _focusSheet() {
    if (!mounted) return;
    _scope.requestFocus();
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: FocusScope(
        node: _scope,
        child: Stack(
          children: [
            _scrim(),
            Align(alignment: Alignment.bottomCenter, child: _sheet(context)),
          ],
        ),
      ),
    );
  }

  Widget _scrim() {
    return Positioned.fill(
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: const ColoredBox(color: albumModalScrim),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * widget.heightFactor;
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

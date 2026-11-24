import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'family_thread_copy.dart';

/// F1b wires onPressed.
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.activeCount, this.onPressed});

  final int activeCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => onPressed?.call(),
      style: TextButton.styleFrom(
        foregroundColor: albumInk,
        minimumSize: const Size(44, 44),
      ),
      child: Text(FamilyThreadCopy.filtersButton(activeCount)),
    );
  }
}

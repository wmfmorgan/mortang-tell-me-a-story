import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'family_thread_copy.dart';

class NoMatchCard extends StatelessWidget {
  const NoMatchCard({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FamilyThreadCopy.noMatch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: albumTerracotta,
                minimumSize: const Size(44, 44),
              ),
              child: const Text(FamilyThreadCopy.clearFilters),
            ),
          ],
        ),
      ),
    );
  }
}

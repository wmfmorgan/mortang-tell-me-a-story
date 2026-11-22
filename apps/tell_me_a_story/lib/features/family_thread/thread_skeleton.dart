import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'family_thread_copy.dart';

class ThreadSkeleton extends StatelessWidget {
  const ThreadSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: FamilyThreadCopy.loadingStories,
      child: const Column(
        children: [
          _SkeletonBeat(),
          _SkeletonBeat(),
          _SkeletonBeat(),
          _SkeletonBeat(),
          _SkeletonBeat(),
        ],
      ),
    );
  }
}

class _SkeletonBeat extends StatelessWidget {
  const _SkeletonBeat();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('thread-skeleton-beat'),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: albumPaleRose,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 40),
          ),
          SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(color: albumPaleRose),
              child: SizedBox(height: 12),
            ),
          ),
        ],
      ),
    );
  }
}

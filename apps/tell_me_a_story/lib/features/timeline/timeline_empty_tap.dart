import 'package:flutter/material.dart';

/// Small empty target at the top-left of a rail. Interactive children stay above it.
class EmptyTap extends StatelessWidget {
  const EmptyTap({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          child: GestureDetector(
            key: const Key('timeline-empty'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox(width: 48, height: 24),
          ),
        ),
      ],
    );
  }
}

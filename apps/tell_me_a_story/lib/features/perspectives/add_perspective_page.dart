import 'package:flutter/material.dart';

/// Placeholder perspective overlay. Full chrome is Task 7.
class AddPerspectivePage extends StatelessWidget {
  const AddPerspectivePage({super.key, required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('add-perspective'),
      body: SizedBox.shrink(key: ValueKey(storyId)),
    );
  }
}

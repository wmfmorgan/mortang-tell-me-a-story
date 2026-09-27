import 'package:flutter/material.dart';

/// Placeholder published reader. Full chrome is Task 5.
class StoryReaderPage extends StatelessWidget {
  const StoryReaderPage({super.key, required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('story-reader'),
      body: SizedBox.shrink(key: ValueKey(storyId)),
    );
  }
}

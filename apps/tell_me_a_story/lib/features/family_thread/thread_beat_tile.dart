import 'package:flutter/material.dart';

import '../../data/stories_api.dart';

class ThreadBeatTile extends StatelessWidget {
  const ThreadBeatTile({super.key, required this.year, required this.story});

  final int year;
  final Story story;

  @override
  Widget build(BuildContext context) {
    final title = story.title?.trim() ?? '';
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label: _label(year, story),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$year', style: theme.labelLarge),
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.titleMedium,
            ),
        ],
      ),
    );
  }
}

String _label(int year, Story story) {
  final parts = <String>['$year'];
  final title = story.title?.trim();
  if (title != null && title.isNotEmpty) parts.add(title);
  final place = story.placeLabel?.trim();
  if (place != null && place.isNotEmpty) parts.add(place);
  final names = <String>[
    for (final person in story.people)
      if (person.name.trim().isNotEmpty) person.name.trim(),
  ];
  if (names.isNotEmpty) parts.add(names.join(', '));
  return parts.join(', ');
}

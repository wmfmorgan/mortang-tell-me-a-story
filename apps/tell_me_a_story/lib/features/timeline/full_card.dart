import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'card_photos.dart';
import 'full_chip.dart';
import 'timeline_zoom.dart';

class FullCard extends StatelessWidget {
  const FullCard({
    super.key,
    required this.story,
    required this.focused,
    required this.branched,
    required this.parentOrigin,
    required this.photos,
    required this.onOpen,
    this.originTag,
    this.onPerson,
  });

  final Story story;
  final bool focused;
  final bool branched;
  final bool parentOrigin;
  final PhotosGateway? photos;
  final VoidCallback onOpen;
  final String? originTag;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  Widget build(BuildContext context) {
    final notes = story.commentCount + story.perspectiveCount;
    final author = (story.authorDisplayName ?? '').trim().isEmpty
        ? 'Member'
        : story.authorDisplayName!.trim();
    final paths = focused
        ? (story.photoPaths.isEmpty
              ? const <String>[]
              : [story.photoPaths.first])
        : story.photoPaths.take(2).toList();
    return Material(
      color: branched ? albumParchment : albumWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(albumCardRadius),
        side: BorderSide(
          color: branched || (focused && parentOrigin)
              ? branchMoss
              : focused
              ? albumTerracotta
              : albumInk.withValues(alpha: 0.2),
          width: branched ? 1 : (focused ? 2 : 1),
        ),
      ),
      child: InkWell(
        key: Key('timeline-card-${story.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(albumCardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(albumCardRadius),
            boxShadow: branched || (focused && parentOrigin)
                ? null
                : [
                    BoxShadow(
                      color: albumInk.withValues(alpha: focused ? 0.08 : 0.04),
                      blurRadius: focused ? 24 : 8,
                      offset: Offset(0, focused ? 8 : 2),
                    ),
                    if (focused && !parentOrigin)
                      BoxShadow(
                        color: albumBlushWash,
                        spreadRadius: 4,
                        blurRadius: 0,
                      ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      storyDateLabelFor(story),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumTerracotta,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final person
                            in story.people.isNotEmpty
                                ? story.people
                                : [
                                    for (final name in story.personNames)
                                      (id: '', name: name),
                                  ])
                          GestureDetector(
                            key: Key(
                              'timeline-person-${story.id}-${person.name}',
                            ),
                            onTap: person.id.isEmpty || onPerson == null
                                ? null
                                : () => onPerson!(person),
                            child: FullChip(
                              icon: Icons.person,
                              label: person.name,
                              filled: focused,
                            ),
                          ),
                        if ((story.placeLabel ?? '').isNotEmpty)
                          FullChip(
                            icon: Icons.location_on,
                            label: story.placeLabel!,
                            filled: focused,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (originTag != null)
                  Text(
                    originTag!,
                    key: Key('timeline-origin-tag-${story.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  story.title ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1.15,
                  ),
                ),
                if (paths.isNotEmpty && photos != null)
                  CardPhotos(paths: paths, photos: photos!, focused: focused),
                if (focused) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: albumInk.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Added by $author',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: albumInk.withValues(alpha: 0.7),
                                ),
                          ),
                          Text(
                            '${countWord(story.photoCount, 'photo', 'photos')} · ${countWord(notes, 'note', 'notes')}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: albumTerracotta,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'quote_card.dart';
import 'thread_photo.dart';
import 'thread_photo_cache.dart';

class PhotoCover extends StatelessWidget {
  const PhotoCover({
    super.key,
    required this.story,
    required this.photos,
    required this.cache,
    required this.line,
  });

  final Story story;
  final PhotosGateway Function() photos;
  final ThreadPhotoCache cache;
  final String line;

  @override
  Widget build(BuildContext context) {
    final version = story.photoEditVersions.isEmpty
        ? 0
        : story.photoEditVersions.first;
    final alt = FamilyThreadCopy.photoAlt(story.title ?? '');
    return Semantics(
      label: alt.isEmpty ? null : alt,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(albumCardRadius),
          ),
          child: ThreadPhoto(
            photos: photos(),
            cache: cache,
            path: story.photoPaths.first,
            editVersion: version,
            displayPx: 480,
            fallback: (_) => FittedBox(
              fit: BoxFit.scaleDown,
              child: QuoteCard(line: line),
            ),
          ),
        ),
      ),
    );
  }
}

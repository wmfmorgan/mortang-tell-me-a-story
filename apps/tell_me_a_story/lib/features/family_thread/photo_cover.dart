import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'quote_card.dart';
import 'thread_photo.dart';
import 'thread_photo_cache.dart';

/// Decode width for the 4:3 cover. A read row is 124pt; 480 covers a 3x screen.
const _coverDecodePx = 480;

class PhotoCover extends StatelessWidget {
  const PhotoCover({
    super.key,
    required this.story,
    required this.photos,
    required this.cache,
    required this.line,
    required this.onQuote,
  });

  final Story story;
  final PhotosGateway Function() photos;
  final ThreadPhotoCache cache;
  final String line;
  final ValueChanged<bool> onQuote;

  @override
  Widget build(BuildContext context) {
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
            editVersion: threadPhotoVersion(story, 0),
            displayPx: _coverDecodePx,
            fallback: (_) => _CoverQuote(line: line, onQuote: onQuote),
          ),
        ),
      ),
    );
  }
}

class _CoverQuote extends StatefulWidget {
  const _CoverQuote({required this.line, required this.onQuote});

  final String line;
  final ValueChanged<bool> onQuote;

  @override
  State<_CoverQuote> createState() => _CoverQuoteState();
}

class _CoverQuoteState extends State<_CoverQuote> {
  @override
  void initState() {
    super.initState();
    _report(true);
  }

  @override
  void dispose() {
    _report(false);
    super.dispose();
  }

  void _report(bool showing) {
    final report = widget.onQuote;
    WidgetsBinding.instance.addPostFrameCallback((_) => report(showing));
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: QuoteCard(line: widget.line),
    );
  }
}

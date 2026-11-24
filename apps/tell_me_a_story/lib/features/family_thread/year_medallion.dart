import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'thread_beat.dart';
import 'thread_filter.dart';
import 'thread_focus.dart';
import 'thread_photo.dart';
import 'thread_photo_cache.dart';

const _diameter = 64.0;

class YearMedallion extends StatelessWidget {
  const YearMedallion({
    super.key,
    required this.beat,
    required this.filter,
    this.photos,
    this.cache,
  });

  final YearBeat beat;
  final ThreadFilter filter;
  final PhotosGateway Function()? photos;
  final ThreadPhotoCache? cache;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: albumTerracotta, width: 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipOval(child: _art()),
        ),
      ),
    );
  }

  Widget _art() {
    final mark = ThreadInitialMark(
      letter: threadInitial(ThreadFocus.representative(beat, filter: filter)),
    );
    final lead = _firstLead(beat.stories, filter);
    final photos = this.photos;
    final cache = this.cache;
    if (lead == null || photos == null || cache == null) return mark;
    return ThreadPhoto(
      photos: photos(),
      cache: cache,
      path: lead.path,
      editVersion: lead.version,
      displayPx: _diameter.round(),
      fallback: (_) => mark,
    );
  }
}

({String path, int version})? _firstLead(
  List<Story> stories,
  ThreadFilter filter,
) {
  for (final story in stories) {
    if (!filter.matches(story)) continue;
    final lead = threadLeadPhoto(story);
    if (lead != null) return lead;
  }
  return null;
}

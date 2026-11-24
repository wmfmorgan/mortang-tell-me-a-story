import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'thread_filter.dart';
import 'thread_photo.dart';
import 'thread_photo_cache.dart';

const _diameter = 112.0;
const _moreFontSize = 13.0;

class DecadeMosaic extends StatelessWidget {
  const DecadeMosaic({
    super.key,
    required this.stories,
    required this.filter,
    this.photos,
    this.cache,
  });

  final List<Story> stories;
  final ThreadFilter filter;
  final PhotosGateway Function()? photos;
  final ThreadPhotoCache? cache;

  @override
  Widget build(BuildContext context) {
    final matched = [
      for (final story in stories)
        if (filter.matches(story)) story,
    ];
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: ClipOval(child: _split(_cells(matched))),
    );
  }

  List<Widget> _cells(List<Story> stories) {
    final shown = stories.length > 4 ? stories.sublist(0, 3) : stories;
    final cells = [for (final story in shown) _tile(story, stories.length)];
    // P4a acceptance "6 stories with +2": +N is the count past four.
    if (stories.length > 4) cells.add(_more(stories.length - 4));
    return cells;
  }

  Widget _tile(Story story, int count) {
    final mark = ThreadInitialMark(
      letter: threadInitial(story),
      fontSize: count == 1 ? threadInitialFontSize : threadMosaicTileFontSize,
    );
    final lead = threadLeadPhoto(story);
    final photos = this.photos;
    final cache = this.cache;
    final child = lead == null || photos == null || cache == null
        ? mark
        : ThreadPhoto(
            photos: photos(),
            cache: cache,
            path: lead.path,
            editVersion: lead.version,
            displayPx: count == 1 ? _diameter.round() : _diameter.round() ~/ 2,
            fallback: (_) => mark,
          );
    return KeyedSubtree(key: const Key('decade-mosaic-tile'), child: child);
  }

  Widget _more(int extra) {
    return ColoredBox(
      key: const Key('decade-mosaic-more'),
      color: albumPaleRose,
      child: Center(
        child: Text(
          '+$extra',
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontSize: _moreFontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

Widget _split(List<Widget> cells) {
  return switch (cells.length) {
    0 => const ColoredBox(color: albumBlush),
    1 => cells[0],
    2 => _pair(cells[0], cells[1]),
    3 => _stack(_pair(cells[0], cells[1]), cells[2]),
    _ => _stack(_pair(cells[0], cells[1]), _pair(cells[2], cells[3])),
  };
}

Widget _pair(Widget left, Widget right) {
  return Row(
    children: [
      Expanded(child: left),
      Expanded(child: right),
    ],
  );
}

Widget _stack(Widget top, Widget bottom) {
  return Column(
    children: [
      Expanded(child: top),
      Expanded(child: bottom),
    ],
  );
}

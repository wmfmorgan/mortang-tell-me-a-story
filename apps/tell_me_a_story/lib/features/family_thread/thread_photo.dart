import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'thread_photo_cache.dart';

const threadInitialFontSize = 28.0;
const threadMosaicTileFontSize = 16.0;

/// Decode width cap for [Image.memory] cacheWidth.
const threadPhotoDecodeCap = 4096;

int threadPhotoVersion(Story story, int index) {
  final versions = story.photoEditVersions;
  if (index < 0 || index >= versions.length) return 0;
  return versions[index];
}

({String path, int version})? threadLeadPhoto(Story story) {
  if (story.photoPaths.isEmpty) return null;
  return (path: story.photoPaths.first, version: threadPhotoVersion(story, 0));
}

String threadInitial(Story story) {
  final title = story.title?.trim() ?? '';
  if (title.isEmpty) return '';
  return title[0].toUpperCase();
}

class ThreadInitialMark extends StatelessWidget {
  const ThreadInitialMark({
    super.key,
    required this.letter,
    this.fontSize = threadInitialFontSize,
  });

  final String letter;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: albumBlush,
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.newsreader(
            color: albumTerracotta,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class ThreadPhoto extends StatefulWidget {
  const ThreadPhoto({
    super.key,
    required this.photos,
    required this.cache,
    required this.path,
    required this.editVersion,
    required this.displayPx,
    required this.fallback,
  });

  final PhotosGateway photos;
  final ThreadPhotoCache cache;
  final String path;
  final int editVersion;
  final int displayPx;
  final WidgetBuilder fallback;

  @override
  State<ThreadPhoto> createState() => _ThreadPhotoState();
}

class _ThreadPhotoState extends State<ThreadPhoto> {
  Uint8List? _bytes;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ThreadPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path &&
        oldWidget.editVersion == widget.editVersion &&
        identical(oldWidget.photos, widget.photos) &&
        identical(oldWidget.cache, widget.cache)) {
      return;
    }
    _bytes = null;
    _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    final key = ThreadPhotoCache.keyFor(widget.path, widget.editVersion);
    final cached = widget.cache.read(key);
    if (cached != null) {
      _bytes = cached;
      return;
    }
    final bytes = await downloadStoryPhotoBytes(
      widget.photos,
      widget.path,
      failure: StoryPhotoFailure.storageOrTransport,
    );
    if (!mounted || ticket != _ticket || bytes == null) return;
    widget.cache.put(key, bytes);
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return widget.fallback(context);
    final px = (widget.displayPx * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, threadPhotoDecodeCap)
        .toInt();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: px,
      errorBuilder: (context, _, _) => widget.fallback(context),
    );
  }
}

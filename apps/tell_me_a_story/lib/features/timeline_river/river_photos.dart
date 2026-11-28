import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'river_beat.dart';

/// Hero, fan, or parchment quote. A failed download stays on the quote.
class RiverPhotos extends StatefulWidget {
  const RiverPhotos({
    super.key,
    required this.story,
    required this.photos,
    required this.fan,
  });

  final Story story;
  final PhotosGateway? photos;
  final bool fan;

  @override
  State<RiverPhotos> createState() => _RiverPhotosState();
}

class _RiverPhotosState extends State<RiverPhotos> {
  final List<Uint8List> _bytes = [];
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gateway = widget.photos;
    final paths = widget.story.photoPaths;
    if (gateway == null || paths.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final loaded = <Uint8List>[];
    final limit = widget.fan ? math.min(3, paths.length) : 1;
    for (final path in paths.take(limit)) {
      final bytes = await _read(gateway, path);
      if (bytes != null) loaded.add(bytes);
    }
    if (!mounted) return;
    setState(() {
      _bytes.addAll(loaded);
      _failed = loaded.isEmpty;
    });
  }

  Future<Uint8List?> _read(PhotosGateway gateway, String path) {
    return downloadStoryPhotoBytes(
      gateway,
      path,
      failure: StoryPhotoFailure.storageOrTransport,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || widget.photos == null || widget.story.photoPaths.isEmpty) {
      return _RiverQuote(story: widget.story);
    }
    if (_bytes.isEmpty) return const _RiverPhotoWait();
    if (widget.fan && _bytes.length > 1) {
      return _RiverFan(story: widget.story, bytes: _bytes);
    }
    return _RiverCover(story: widget.story, bytes: _bytes.first);
  }
}

class _RiverPhotoWait extends StatelessWidget {
  const _RiverPhotoWait();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 4 / 3,
      child: ColoredBox(color: sageTint),
    );
  }
}

class _RiverCover extends StatelessWidget {
  const _RiverCover({required this.story, required this.bytes});

  final Story story;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: riverPhotoAlt(story),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(albumCardRadius),
        ),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _RiverQuote(story: story),
          ),
        ),
      ),
    );
  }
}

class _RiverFan extends StatelessWidget {
  const _RiverFan({required this.story, required this.bytes});

  final Story story;
  final List<Uint8List> bytes;

  @override
  Widget build(BuildContext context) {
    final extra = story.photoPaths.length - bytes.length;
    return Semantics(
      image: true,
      label: riverPhotoAlt(story),
      child: SizedBox(
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (bytes.length > 1) _turned(bytes.first, -5),
            if (bytes.length > 2) _turned(bytes[1], 4),
            _frame(bytes.last),
            if (extra > 0) _chip(context, extra),
          ],
        ),
      ),
    );
  }

  Widget _turned(Uint8List bytes, double degrees) {
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: _frame(bytes),
    );
  }

  Widget _frame(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(albumCardRadius),
      child: Image.memory(
        bytes,
        width: 160,
        height: 120,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _chip(BuildContext context, int extra) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: albumTerracotta,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '+$extra',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: albumParchment),
          ),
        ),
      ),
    );
  }
}

class _RiverQuote extends StatelessWidget {
  const _RiverQuote({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final line = riverFirstLine(story.body);
    final theme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(albumCardRadius),
        border: Border.all(color: albumSage.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“',
              key: const Key('river-quote'),
              style: theme.titleLarge?.copyWith(color: albumTerracotta),
            ),
            if (line.isNotEmpty)
              Text(
                line,
                key: const Key('river-no-photo-line'),
                style: theme.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }
}

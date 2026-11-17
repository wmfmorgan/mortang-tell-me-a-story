import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../stories/photo_frame.dart';

class CardPhotos extends StatefulWidget {
  const CardPhotos({
    super.key,
    required this.paths,
    required this.photos,
    required this.focused,
  });

  final List<String> paths;
  final PhotosGateway photos;
  final bool focused;

  @override
  State<CardPhotos> createState() => _CardPhotosState();
}

class _CardPhotosState extends State<CardPhotos> {
  final Map<String, Uint8List> _bytes = {};
  final Map<String, double> _aspect = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final path in widget.paths) {
      final bytes = await downloadStoryPhotoBytes(
        widget.photos,
        path,
        failure: StoryPhotoFailure.storageOrTransport,
      );
      if (bytes == null) continue;
      if (!mounted) return;
      setState(() {
        _bytes[path] = bytes;
        _aspect[path] = encodedPhotoAspect(bytes) ?? (16 / 9);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = [
      for (final path in widget.paths)
        if (_bytes[path] != null) path,
    ];
    if (ready.isEmpty) return const SizedBox.shrink();
    final shared = ready.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gaps = 12.0 * (ready.length - 1);
          final cellWidth = ready.length == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gaps) / ready.length;
          final height = shared
              ? cardPhotoRowHeight(focused: widget.focused)
              : cardPhotoHeight(
                  width: cellWidth,
                  imageAspect: _aspect[ready.first] ?? (16 / 9),
                  focused: widget.focused,
                );
          return SizedBox(
            key: Key('timeline-card-photos-${ready.first}'),
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < ready.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: albumParchment,
                          child: Image.memory(
                            _bytes[ready[i]]!,
                            height: height,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

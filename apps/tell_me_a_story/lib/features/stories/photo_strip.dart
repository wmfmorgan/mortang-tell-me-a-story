import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';

const photoUploadFailureCopy =
    'Couldn’t upload the photo. Check your connection and try again.';

const photoUploadRetryLabel = 'Try again';

/// Horizontal add / thumbnail / retry strip for story capture.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    this.previews = const {},
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
    required this.uploadFailed,
    required this.canAdd,
    this.tileSize = 148,
  });

  final List<Photo> photos;
  final Map<String, Uint8List> previews;
  final VoidCallback onAdd;
  final ValueChanged<Photo> onRemove;
  final VoidCallback onRetry;
  final bool uploadFailed;
  final bool canAdd;

  /// Edge length of each photo card and the dashed add tile.
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uploadFailed) ...[
          const Text(photoUploadFailureCopy),
          TextButton(
            onPressed: onRetry,
            child: const Text(photoUploadRetryLabel),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: tileSize,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final photo in photos)
                  _Thumb(
                    photo: photo,
                    preview: previews[photo.id],
                    onRemove: onRemove,
                    size: tileSize,
                  ),
                if (canAdd) _AddTile(onAdd: onAdd, size: tileSize),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd, required this.size});

  final VoidCallback onAdd;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: CustomPaint(
        painter: const _DashedCardPainter(color: albumSage),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('photo-add'),
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: size,
              height: size,
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: albumSage,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.onRemove,
    required this.size,
    this.preview,
  });

  final Photo photo;
  final Uint8List? preview;
  final ValueChanged<Photo> onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        key: const Key('photo-thumb'),
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: albumSage.withValues(alpha: 0.35)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: preview == null
                      ? const ColoredBox(
                          color: albumParchment,
                          child: Icon(Icons.photo_outlined, color: albumSage),
                        )
                      : Image.memory(
                          preview!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const ColoredBox(
                              color: albumParchment,
                              child: Icon(
                                Icons.photo_outlined,
                                color: albumSage,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                key: const Key('photo-remove'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: albumParchment.withValues(alpha: 0.92),
                  foregroundColor: albumInk,
                ),
                onPressed: () => onRemove(photo),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedCardPainter extends CustomPainter {
  const _DashedCardPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 7).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCardPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

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
    this.tileWidth,
    this.tileHeight,
    this.addLabel,
    this.addHint,
    this.columns,
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

  /// Overrides [tileSize] when the row should be landscape cards.
  final double? tileWidth;
  final double? tileHeight;

  /// Optional label inside the dashed add tile.
  final String? addLabel;

  /// Second line under [addLabel], such as the photo cap.
  final String? addHint;

  /// When set, tiles fill this many columns at a 4:3 ratio.
  /// The reader leaves this null and keeps the horizontal strip.
  final int? columns;

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
        if (columns == null)
          SizedBox(
            height: tileHeight ?? tileSize,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tiles(tileWidth ?? tileSize, tileHeight ?? tileSize),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final count = columns!;
              final width = ((constraints.maxWidth - gap * (count - 1)) / count)
                  .clamp(72.0, 420.0);
              final height = width * 3 / 4;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _tiles(width, height, padRight: false),
              );
            },
          ),
      ],
    );
  }

  List<Widget> _tiles(double width, double height, {bool padRight = true}) {
    return [
      for (final photo in photos)
        _Thumb(
          photo: photo,
          preview: previews[photo.id],
          onRemove: onRemove,
          width: width,
          height: height,
          padRight: padRight,
        ),
      if (canAdd)
        _AddTile(
          onAdd: onAdd,
          width: width,
          height: height,
          label: addLabel,
          hint: addHint,
          padRight: padRight,
        ),
    ];
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.onAdd,
    required this.width,
    required this.height,
    this.label,
    this.hint,
    this.padRight = true,
  });

  final VoidCallback onAdd;
  final double width;
  final double height;
  final String? label;
  final String? hint;
  final bool padRight;

  @override
  Widget build(BuildContext context) {
    final labeled = label != null;
    return Padding(
      padding: EdgeInsets.only(right: padRight ? 12 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('photo-add'),
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: _DashedCardPainter(
              color: labeled ? albumInk.withValues(alpha: 0.28) : albumSage,
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: labeled ? _labeledBody(context) : _iconOnly(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconOnly() {
    return const Center(
      child: Icon(Icons.add_a_photo_outlined, color: albumSage, size: 28),
    );
  }

  Widget _labeledBody(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: albumInk, fontWeight: FontWeight.w600);
    final hintStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: albumInk.withValues(alpha: 0.55), fontSize: 11);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF4EFEA),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.add_a_photo_outlined,
                  color: albumTerracotta,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label!, textAlign: TextAlign.center, style: labelStyle),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(hint!, textAlign: TextAlign.center, style: hintStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.onRemove,
    required this.width,
    required this.height,
    this.preview,
    this.padRight = true,
  });

  final Photo photo;
  final Uint8List? preview;
  final ValueChanged<Photo> onRemove;
  final double width;
  final double height;
  final bool padRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: padRight ? 12 : 0),
      child: SizedBox(
        key: const Key('photo-thumb'),
        width: width,
        height: height,
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

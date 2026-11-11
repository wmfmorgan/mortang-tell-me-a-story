import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/photo.dart';

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
    this.addEnabled = true,
    this.canRemove,
    this.onToggleHero,
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
  /// Null keeps the horizontal strip.
  final int? columns;

  /// When false the add tile is dimmed. It still accepts taps.
  final bool addEnabled;

  /// When null, every thumb shows Remove. When set, only a true result does.
  final bool Function(Photo)? canRemove;

  /// When set, each thumb shows a hero icon. The first photo by sort order
  /// is the hero until another is chosen.
  final ValueChanged<Photo>? onToggleHero;

  @override
  Widget build(BuildContext context) {
    final heroId = _heroPhotoId(photos);
    final count = columns;
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
        if (count == null)
          SizedBox(
            height: tileHeight ?? tileSize,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _photoTiles(
                  this,
                  tileWidth ?? tileSize,
                  tileHeight ?? tileSize,
                  heroId,
                ),
              ),
            ),
          )
        else
          _TileGrid(
            columns: count,
            tilesFor: (width, height) =>
                _photoTiles(this, width, height, heroId, padRight: false),
          ),
      ],
    );
  }
}

/// The thumbs of [strip], then its add tile when it allows adding.
List<Widget> _photoTiles(
  PhotoStrip strip,
  double width,
  double height,
  String? heroId, {
  bool padRight = true,
}) {
  return [
    for (final photo in strip.photos)
      _Thumb(
        photo: photo,
        preview: strip.previews[photo.id],
        onRemove: strip.onRemove,
        showRemove: strip.canRemove?.call(photo) ?? true,
        isHero: photo.id == heroId,
        onToggleHero: strip.onToggleHero,
        width: width,
        height: height,
        padRight: padRight,
      ),
    if (strip.canAdd)
      _AddTile(
        onAdd: strip.onAdd,
        width: width,
        height: height,
        label: strip.addLabel,
        hint: strip.addHint,
        padRight: padRight,
        enabled: strip.addEnabled,
      ),
  ];
}

/// Tiles filling [columns] columns at a 4:3 ratio.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.columns, required this.tilesFor});

  final int columns;
  final List<Widget> Function(double width, double height) tilesFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
            .clamp(72.0, 420.0);
        final height = width * 3 / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tilesFor(width, height),
        );
      },
    );
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
    this.enabled = true,
  });

  final VoidCallback onAdd;
  final double width;
  final double height;
  final String? label;
  final String? hint;
  final bool padRight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return Padding(
      padding: EdgeInsets.only(right: padRight ? 12 : 0),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('photo-add'),
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _DashedCardPainter(
                color: text != null
                    ? albumSage.withValues(alpha: 0.6)
                    : albumSage,
              ),
              child: SizedBox(
                width: width,
                height: height,
                child: text != null
                    ? _AddTileLabel(label: text, hint: hint)
                    : const _AddTileIcon(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTileIcon extends StatelessWidget {
  const _AddTileIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.add_a_photo_outlined, color: albumSage, size: 28),
    );
  }
}

class _AddTileLabel extends StatelessWidget {
  const _AddTileLabel({required this.label, required this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.sourceSans3(
      color: albumInk,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    final hintStyle = GoogleFonts.sourceSans3(color: albumSage, fontSize: 10);
    final hintText = hint;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: albumTerracotta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: labelStyle),
            if (hintText != null) ...[
              const SizedBox(height: 2),
              Text(hintText, textAlign: TextAlign.center, style: hintStyle),
            ],
          ],
        ),
      ),
    );
  }
}

String? _heroPhotoId(List<Photo> photos) {
  if (photos.isEmpty) return null;
  final sorted = [...photos]..sort(comparePhotoOrder);
  return sorted.first.id;
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.onRemove,
    required this.showRemove,
    required this.isHero,
    required this.width,
    required this.height,
    this.onToggleHero,
    this.preview,
    this.padRight = true,
  });

  final Photo photo;
  final Uint8List? preview;
  final ValueChanged<Photo> onRemove;
  final bool showRemove;
  final bool isHero;
  final ValueChanged<Photo>? onToggleHero;
  final double width;
  final double height;
  final bool padRight;

  @override
  Widget build(BuildContext context) {
    final toggleHero = onToggleHero;
    return Padding(
      padding: EdgeInsets.only(right: padRight ? 12 : 0),
      child: SizedBox(
        key: const Key('photo-thumb'),
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: _ThumbImage(preview: preview)),
            if (toggleHero != null)
              Positioned(
                top: 4,
                left: 4,
                child: _ThumbAction(
                  key: Key('photo-hero-${photo.id}'),
                  foreground: isHero ? albumTerracotta : albumInk,
                  onPressed: () => toggleHero(photo),
                  icon: isHero ? Icons.star : Icons.star_border,
                ),
              ),
            if (showRemove)
              Positioned(
                top: 4,
                right: 4,
                child: _ThumbAction(
                  key: const Key('photo-remove'),
                  foreground: albumInk,
                  onPressed: () => onRemove(photo),
                  icon: Icons.close,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThumbImage extends StatelessWidget {
  const _ThumbImage({required this.preview});

  final Uint8List? preview;

  @override
  Widget build(BuildContext context) {
    final bytes = preview;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: albumSage.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: bytes == null
            ? const ColoredBox(
                color: albumParchment,
                child: Icon(Icons.photo_outlined, color: albumSage),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: albumParchment,
                    child: Icon(Icons.photo_outlined, color: albumSage),
                  );
                },
              ),
      ),
    );
  }
}

class _ThumbAction extends StatelessWidget {
  const _ThumbAction({
    super.key,
    required this.foreground,
    required this.onPressed,
    required this.icon,
  });

  final Color foreground;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      iconSize: 18,
      style: IconButton.styleFrom(
        backgroundColor: albumParchment.withValues(alpha: 0.92),
        foregroundColor: foreground,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'thread_photo.dart';
import 'thread_photo_cache.dart';

const _frontW = 96.0;
const _frontH = 72.0;
const _shiftX = 12.0;
const _shiftY = 6.0;
const _bleed = 8.0;

class PhotoFan extends StatelessWidget {
  const PhotoFan({
    super.key,
    required this.story,
    required this.photos,
    required this.cache,
  });

  final Story story;
  final PhotosGateway Function() photos;
  final ThreadPhotoCache cache;

  static const designWidth = _bleed + _shiftX + _frontW + _shiftX + _bleed;
  static const designHeight = _bleed + _shiftY + _frontH + _bleed;

  @override
  Widget build(BuildContext context) {
    final count = story.photoPaths.length;
    final shown = count < 3 ? count : 3;
    final alt = FamilyThreadCopy.fanAlt(story.title ?? '', count);
    return Semantics(
      label: alt.isEmpty ? null : alt,
      excludeSemantics: true,
      child: SizedBox(
        width: designWidth,
        height: designHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = shown - 1; i >= 1; i--) _at(i),
            _at(0),
            if (count > 3) _chip(count - 3),
          ],
        ),
      ),
    );
  }

  Widget _at(int index) {
    final place = _place(index);
    return Positioned(
      left: place.dx,
      top: place.dy,
      width: _frontW,
      height: _frontH,
      child: Transform.rotate(
        angle: place.turns,
        child: _FanPrint(
          story: story,
          index: index,
          photos: photos,
          cache: cache,
        ),
      ),
    );
  }

  Widget _chip(int extra) {
    return Positioned(
      left: _bleed + _shiftX + _frontW - 36,
      top: _bleed + _shiftY + _frontH - 20,
      child: _FanChip(extra: extra),
    );
  }
}

({double dx, double dy, double turns}) _place(int index) {
  if (index == 0) {
    return (dx: _bleed + _shiftX, dy: _bleed + _shiftY, turns: 0);
  }
  if (index == 1) {
    return (dx: _bleed, dy: _bleed, turns: -6 * math.pi / 180);
  }
  return (dx: _bleed + _shiftX * 2, dy: _bleed, turns: 5 * math.pi / 180);
}

class _FanPrint extends StatelessWidget {
  const _FanPrint({
    required this.story,
    required this.index,
    required this.photos,
    required this.cache,
  });

  final Story story;
  final int index;
  final PhotosGateway Function() photos;
  final ThreadPhotoCache cache;

  @override
  Widget build(BuildContext context) {
    final versions = story.photoEditVersions;
    final version = index < versions.length ? versions[index] : 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        border: Border.all(color: albumPillBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ThreadPhoto(
          photos: photos(),
          cache: cache,
          path: story.photoPaths[index],
          editVersion: version,
          displayPx: _frontW.round(),
          fallback: (_) => const ColoredBox(color: albumParchment),
        ),
      ),
    );
  }
}

class _FanChip extends StatelessWidget {
  const _FanChip({required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('photo-fan-chip'),
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '+$extra',
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'all_stories_logic.dart';

/// Ink at 70% on parchment. That composite is the #6A6358 dim floor.
Color allStoriesDimInk() {
  return Color.alphaBlend(albumInk.withValues(alpha: 0.7), albumParchment);
}

/// Spec-allowed fill. Soft parchment veil over a dimmed cover.
const allStoriesVeilOpacity = 0.45;

class AllStoriesCard extends StatelessWidget {
  const AllStoriesCard({
    super.key,
    required this.story,
    required this.mark,
    required this.familyName,
    required this.query,
    required this.filterActive,
    required this.undimmed,
    required this.thumb,
    required this.onOpen,
    required this.onOpenBranch,
  });

  final Story story;
  final SpawnMark mark;
  final String familyName;
  final String query;
  final bool filterActive;
  final bool undimmed;
  final Uint8List? thumb;
  final VoidCallback onOpen;
  final ValueChanged<TreeFamily> onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final textColor = undimmed ? albumInk : allStoriesDimInk();
    final border = undimmed && filterActive
        ? Border.all(color: albumTerracotta, width: 2)
        : Border.all(color: albumPillBorder);
    return Semantics(
      key: Key('all-stories-card-${story.id}'),
      container: true,
      explicitChildNodes: true,
      button: true,
      label: _label(),
      onTap: onOpen,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(albumCardRadius),
          border: border,
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(albumCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cover(),
                if (_dateLine() case final date?) ...[
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: GoogleFonts.sourceSans3(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (_title() case final title?) ...[
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _pills(textColor),
                if (story.placeLabel != null &&
                    story.placeLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: undimmed ? albumSage : allStoriesDimInk(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          story.placeLabel!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sourceSans3(
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover() {
    Widget photo = thumb == null || thumb!.isEmpty
        ? const ColoredBox(color: albumParchment)
        : Image.memory(
            thumb!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            width: double.infinity,
            height: 140,
          );
    if (!undimmed && thumb != null && thumb!.isNotEmpty) {
      photo = ColorFiltered(colorFilter: _grayscale, child: photo);
    }
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          if (!undimmed)
            ColoredBox(
              color: albumParchment.withValues(alpha: allStoriesVeilOpacity),
            ),
          if (mark.startedTimeline)
            Positioned(
              top: 8,
              right: 8,
              child: _Ring(
                key: Key('all-stories-ring-${story.id}'),
                color: undimmed ? albumSage : allStoriesDimInk(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pills(Color textColor) {
    final needle = query.trim().toLowerCase();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (mark.isOrigin)
          _OriginLabel(
            text: mark.inheritedFromName == null
                ? 'Origin'
                : 'Origin · from ${mark.inheritedFromName}',
            color: undimmed ? albumSage : allStoriesDimInk(),
          ),
        for (final branch in mark.branches)
          Semantics(
            button: true,
            label: 'Open the ${branch.name} timeline',
            onTap: () => onOpenBranch(branch),
            child: ExcludeSemantics(
              child: TextButton(
                key: Key('all-stories-branch-${story.id}-${branch.id}'),
                onPressed: () => onOpenBranch(branch),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: textColor,
                  backgroundColor: albumPillFill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: albumPillBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: textColor,
                    ),
                    const SizedBox(width: 4),
                    Text(branch.name),
                  ],
                ),
              ),
            ),
          ),
        for (final person in story.people)
          _PersonPill(
            name: person.name,
            color: textColor,
            matched:
                needle.isNotEmpty && person.name.toLowerCase().contains(needle),
          ),
      ],
    );
  }

  String _label() {
    final parts = <String>[];
    final title = _title();
    final date = _dateLine();
    if (title != null) parts.add(title);
    if (date != null) parts.add(date);
    if (story.people.isNotEmpty) {
      parts.add(story.people.map((person) => person.name).join(', '));
    }
    var label = parts.join(', ');
    if (filterActive) {
      final suffix = undimmed ? 'matches' : 'not a match';
      label = label.isEmpty ? suffix : '$label, $suffix';
    }
    final spawn = _spawnPhrase();
    if (spawn.isNotEmpty) {
      label = label.isEmpty ? spawn : '$label, $spawn';
    }
    return label;
  }

  String _spawnPhrase() {
    final parts = <String>[];
    if (mark.isOrigin) parts.add('Started the $familyName timeline');
    for (final branch in mark.branches) {
      parts.add('Started the ${branch.name} timeline');
    }
    return parts.join(', ');
  }

  String? _title() {
    final title = story.title?.trim();
    if (title == null || title.isEmpty) return null;
    return title;
  }

  String? _dateLine() {
    final start = story.timeframeStart;
    if (start == null) return null;
    return storyDateLabel(
      StoryDate.fromRow(start, story.timeframeEnd, story.datePrecision),
    );
  }
}

class _OriginLabel extends StatelessWidget {
  const _OriginLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.account_tree_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sourceSans3(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonPill extends StatelessWidget {
  const _PersonPill({
    required this.name,
    required this.color,
    required this.matched,
  });

  final String name;
  final Color color;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: albumPillFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: matched ? albumTerracotta : albumPillBorder,
          width: matched ? 2 : 1,
        ),
      ),
      child: Text(
        name,
        style: GoogleFonts.sourceSans3(color: color, fontSize: 14),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: albumParchment,
          shape: BoxShape.circle,
        ),
        child: CustomPaint(painter: _DashedRingPainter(color)),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 3.0;
    const gap = 2.0;
    final radius = size.width / 2;
    final circumference = 2 * math.pi * radius;
    final count = math.max(1, (circumference / (dash + gap)).floor());
    final sweep = (dash / circumference) * 2 * math.pi;
    final gapSweep = (gap / circumference) * 2 * math.pi;
    var start = -math.pi / 2;
    final rect = Offset.zero & size;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect.deflate(1), start, sweep, false, paint);
      start += sweep + gapSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

const _grayscale = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

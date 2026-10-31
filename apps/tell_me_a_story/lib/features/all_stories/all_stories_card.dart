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

const allStoriesMotion = Duration(milliseconds: 240);

Duration allStoriesMotionOf(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : allStoriesMotion;
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
    final motion = allStoriesMotionOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: undimmed ? 0 : 1),
      duration: motion,
      builder: (context, dim, _) {
        final textColor =
            Color.lerp(albumInk, allStoriesDimInk(), dim) ?? albumInk;
        final accent =
            Color.lerp(albumSage, allStoriesDimInk(), dim) ?? albumSage;
        final borderColor =
            Color.lerp(
              filterActive ? albumTerracotta : albumPillBorder,
              albumPillBorder,
              dim,
            ) ??
            albumPillBorder;
        final fromWidth = filterActive ? 2.0 : 1.0;
        final borderWidth = fromWidth + (1 - fromWidth) * dim;
        return _frame(
          dim: dim,
          textColor: textColor,
          accent: accent,
          borderColor: borderColor,
          borderWidth: borderWidth,
        );
      },
    );
  }

  Widget _frame({
    required double dim,
    required Color textColor,
    required Color accent,
    required Color borderColor,
    required double borderWidth,
  }) {
    return Semantics(
      key: Key('all-stories-card-${story.id}'),
      container: true,
      explicitChildNodes: true,
      button: true,
      label: _label(),
      onTap: onOpen,
      child: AllStoriesFocusTarget(
        radius: albumCardRadius,
        childBuilder: (node) => Material(
          color: albumParchment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(albumCardRadius),
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
          child: InkWell(
            focusNode: node,
            onTap: onOpen,
            borderRadius: BorderRadius.circular(albumCardRadius),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cover(dim, accent),
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
                  _pills(textColor, accent),
                  if (placeHeading(story) case final place?) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place,
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
      ),
    );
  }

  Widget _cover(double dim, Color accent) {
    final bytes = thumb;
    Widget photo = switch (bytes) {
      final image? when image.isNotEmpty => Image.memory(
        image,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: 140,
      ),
      _ => const ColoredBox(color: albumParchment),
    };
    if (bytes != null && bytes.isNotEmpty && dim > 0) {
      photo = ColorFiltered(
        colorFilter: ColorFilter.matrix(_grayAt(dim)),
        child: photo,
      );
    }
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          ColoredBox(
            color: albumParchment.withValues(
              alpha: allStoriesVeilOpacity * dim,
            ),
          ),
          if (mark.startedTimeline)
            Positioned(
              top: 8,
              right: 8,
              child: _Ring(
                key: Key('all-stories-ring-${story.id}'),
                color: accent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pills(Color textColor, Color accent) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (mark.startedTimeline)
          _OriginPill(
            text: mark.inheritedFromName == null
                ? 'Origin'
                : 'Origin · from ${mark.inheritedFromName}',
            color: accent,
          ),
        for (final branch in mark.branches)
          Semantics(
            button: true,
            label: 'Open the ${branch.name} timeline',
            onTap: () => onOpenBranch(branch),
            child: AllStoriesFocusTarget(
              radius: 20,
              childBuilder: (node) => TextButton(
                key: Key('all-stories-branch-${story.id}-${branch.id}'),
                focusNode: node,
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
                    Text(
                      branch.name,
                      style: GoogleFonts.sourceSans3(color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        for (final person in story.people)
          _PersonPill(
            name: person.name,
            color: textColor,
            matched: nameMatches(person.name, query),
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

class _OriginPill extends StatelessWidget {
  const _OriginPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumPillFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: albumPillBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
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
        ),
      ),
    );
  }
}

class AllStoriesFocusTarget extends StatefulWidget {
  const AllStoriesFocusTarget({
    super.key,
    required this.childBuilder,
    this.radius = 12,
  });

  final Widget Function(FocusNode node) childBuilder;
  final double radius;

  @override
  State<AllStoriesFocusTarget> createState() => _AllStoriesFocusTargetState();
}

class _AllStoriesFocusTargetState extends State<AllStoriesFocusTarget> {
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The ring sits 2px outside the child so a parchment offset plus a
    // 2px outline does not widen pills in the wrap.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.childBuilder(_node),
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: allStoriesMotionOf(context),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius + 4),
                border: Border.all(
                  color: _node.hasFocus
                      ? albumTerracotta
                      : albumTerracotta.withValues(alpha: 0),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AllStoriesDashedRing extends StatelessWidget {
  const AllStoriesDashedRing({super.key, this.size = 16, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
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

const _identity = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0,
];

const _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
];

List<double> _grayAt(double t) {
  return [
    for (var i = 0; i < _grayscale.length; i++)
      _identity[i] + (_grayscale[i] - _identity[i]) * t,
  ];
}

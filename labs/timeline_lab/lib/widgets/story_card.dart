import 'package:flutter/material.dart';

import '../model/lab_models.dart';
import '../renderers/story_marker.dart';
import '../theme/lab_theme.dart';

/// Album card (album_theme.dart CardTheme): parchment fill, sage border,
/// Newsreader title. Shared by the widget-based renderers and the selection
/// panel.
///
/// Unmatched (dimmed) cards draw text in [labDimmedInk], the lightest text
/// the dim rule allows, and fade only non-text decoration to
/// [labDimOpacity]. A plain `Opacity` wrapper would push text below that
/// floor.
class StoryCard extends StatelessWidget {
  StoryCard({
    required this.story,
    required this.dataset,
    required this.matched,
    required this.selected,
    this.onTap,
    this.compact = false,
  }) : super(key: Key('card-${story.id}'));

  static const width = 280.0;

  final LabStory story;
  final LabDataset dataset;
  final bool matched;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ink = matched ? labInk : labDimmedInk;
    final decorationAlpha = matched ? 1.0 : labDimOpacity;
    final origin = isOrigin(story, dataset);
    final borderColor = selected
        ? labTerracotta
        : origin
        ? labMoss
        : labSageLine;
    final borderWidth = selected || origin
        ? LabStroke.mark
        : LabStroke.hairline;
    final names = dataset.personNames(story);
    final place = dataset.placeLabel(story);

    return SizedBox(
      width: width,
      child: Material(
        color: labParchment,
        shape: labContainerShape(
          LabRadius.card,
          side: BorderSide(
            color: borderColor.withValues(
              alpha: borderColor.a * decorationAlpha,
            ),
            width: borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? LabSpace.s : LabSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dataset.dateLabel(story),
                  style: theme.labelMedium?.copyWith(
                    color: matched ? labTerracotta : labDimmedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium?.copyWith(color: ink),
                ),
                if (!compact && (origin || names.isNotEmpty)) ...[
                  const SizedBox(height: LabSpace.s),
                  Wrap(
                    spacing: LabSpace.xs,
                    runSpacing: LabSpace.xs,
                    children: [
                      if (origin)
                        _Pill(
                          label: 'Origin',
                          ink: ink,
                          alpha: decorationAlpha,
                          border: labMoss,
                        ),
                      for (final n in names.take(3))
                        _Pill(label: n, ink: ink, alpha: decorationAlpha),
                    ],
                  ),
                ],
                if (!compact && (place != null || story.photoCount > 0)) ...[
                  const SizedBox(height: LabSpace.s),
                  Row(
                    children: [
                      if (place != null) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: matched ? labSage : labDimmedInk,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            place,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelMedium?.copyWith(color: ink),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (story.photoCount > 0) ...[
                        Icon(Icons.photo_outlined, size: 16, color: ink),
                        const SizedBox(width: 2),
                        Text(
                          '${story.photoCount}',
                          style: theme.labelMedium?.copyWith(color: ink),
                        ),
                      ],
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
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.ink,
    required this.alpha,
    this.border = labPillBorder,
  });

  final String label;
  final Color ink;
  final double alpha;
  final Color border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: labPillFill.withValues(alpha: alpha),
      border: Border.all(color: border.withValues(alpha: alpha)),
      borderRadius: BorderRadius.circular(LabRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: LabSpace.s, vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink),
      ),
    ),
  );
}

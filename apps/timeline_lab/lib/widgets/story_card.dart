import 'package:flutter/material.dart';

import '../model/lab_models.dart';
import '../renderers/story_marker.dart';
import '../theme/lab_theme.dart';

/// Shared card used by the widget-based renderers and the selection panel.
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
    final borderColor = selected
        ? labTerracotta
        : isOrigin(story, dataset)
        ? labMoss
        : labBorder;
    final borderWidth = borderColor == labBorder ? 1.0 : 2.0;
    final names = dataset.personNames(story);
    final place = dataset.placeLabel(story);

    return SizedBox(
      width: width,
      child: Material(
        color: labSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LabRadius.card),
          side: BorderSide(
            color: borderColor.withValues(alpha: decorationAlpha),
            width: borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 12),
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
                  style: (compact ? theme.titleSmall : theme.titleMedium)
                      ?.copyWith(color: ink),
                ),
                if (!compact && names.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final n in names.take(3))
                        _Pill(label: n, ink: ink, alpha: decorationAlpha),
                    ],
                  ),
                ],
                if (!compact && (place != null || story.photoCount > 0)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (place != null)
                        Expanded(
                          child: Text(
                            place,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelMedium?.copyWith(color: ink),
                          ),
                        )
                      else
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
  const _Pill({required this.label, required this.ink, required this.alpha});

  final String label;
  final Color ink;
  final double alpha;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: labPillFill.withValues(alpha: alpha),
      border: Border.all(color: labPillBorder.withValues(alpha: alpha)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink),
      ),
    ),
  );
}

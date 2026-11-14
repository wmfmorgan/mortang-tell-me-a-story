import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'center_on_dot.dart';
import 'far_dot.dart';
import 'origin_dot.dart';
import 'timeline_branching.dart';
import 'timeline_zoom.dart';

class FarDecadeRow extends StatelessWidget {
  const FarDecadeRow({
    super.key,
    required this.band,
    required this.focused,
    required this.opacity,
    required this.highlight,
    required this.branching,
    this.originStoryId,
    required this.onDot,
    required this.onYear,
    required this.onOpenBranch,
  });

  final DecadeBand band;
  final bool focused;
  final double opacity;
  final Story? highlight;
  final RailBranching branching;
  final String? originStoryId;
  final ValueChanged<Story> onDot;
  final ValueChanged<int> onYear;
  final ValueChanged<String> onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final stories = band.stories;
    final count = countWord(band.stories.length, 'story', 'stories');
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: Key('timeline-decade-${band.startYear}'),
            onTap: () => onYear(band.startYear),
            child: Text(
              band.label,
              style: focused
                  ? Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                  : Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (focused)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: albumTerracotta,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              focused ? '$count preserved' : count,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: focused
                    ? albumTerracotta
                    : albumInk.withValues(alpha: 0.6),
                fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
    final plain = <Widget>[];
    final branched = <Widget>[];
    for (final story in stories) {
      final frame = branching.frameFor(story);
      final highlighted = focused && story.id == highlight?.id;
      final origin = story.id == originStoryId;
      if (frame.parent != null) {
        branched.add(
          _farParent(context, frame, highlighted: highlighted, origin: origin),
        );
      } else if (frame.branchesStory) {
        branched.add(
          _farBranch(context, frame, highlighted: highlighted, origin: origin),
        );
      } else {
        final dot = FarDot(
          story: story,
          highlighted: highlighted,
          origin: origin,
          onTap: () => onDot(story),
        );
        plain.add(
          origin ? OriginDot(highlighted: highlighted, child: dot) : dot,
        );
      }
    }
    final dots = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [...plain, ...branched],
        ),
      ],
    );
    return Opacity(
      opacity: opacity,
      child: Padding(
        key: Key('timeline-decade-row-${band.startYear}'),
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: label),
            ),
            SizedBox(
              width: 48,
              child: GestureDetector(
                key: Key('timeline-decade-node-${band.startYear}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onYear(band.startYear),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Center(
                    child: Container(
                      width: focused ? 28 : 14,
                      height: focused ? 28 : 14,
                      decoration: BoxDecoration(
                        color: focused
                            ? albumTerracotta.withValues(alpha: 0.2)
                            : albumDialogSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: focused
                              ? albumTerracotta
                              : albumInk.withValues(alpha: 0.35),
                          width: focused ? 1.5 : 2,
                        ),
                      ),
                      child: focused
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: albumTerracotta,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: dots,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _farParent(
    BuildContext context,
    StoryFrame frame, {
    required bool highlighted,
    required bool origin,
  }) {
    final story = frame.story;
    final mark = decadeParentMark(
      context: context,
      frame: frame,
      dot: FarDot(
        story: story,
        highlighted: highlighted,
        origin: origin,
        onTap: () => onDot(story),
      ),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: calloutLabelWidthFar,
      onOpen: onOpenBranch,
    );
    return CenterOnDot(
      dotExtent: calloutHit,
      dotTop: mark.dotTop,
      child: mark.child,
    );
  }

  Widget _farBranch(
    BuildContext context,
    StoryFrame frame, {
    required bool highlighted,
    required bool origin,
  }) {
    final story = frame.story;
    final placed = placeBranchCallout(
      context: context,
      frame: frame,
      side: CalloutSide.right,
      dot: FarDot(
        story: story,
        highlighted: highlighted,
        origin: origin,
        onTap: () => onDot(story),
      ),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: calloutLabelWidthFar,
      onOpen: onOpenBranch,
    );
    return CenterOnDot(
      dotExtent: calloutHit,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          BranchCalloutTarget(
            frame: frame,
            onOpen: onOpenBranch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: calloutHit,
                  height: calloutHit,
                  child: placed.ringHit,
                ),
                placed.lane,
              ],
            ),
          ),
          placed.dot,
        ],
      ),
    );
  }
}

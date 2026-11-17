import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'hang_parent_callout.dart';
import 'rail_gutter.dart';
import 'callout_layout.dart';
import 'timeline_zoom.dart';

class DialRow extends StatelessWidget {
  const DialRow({
    super.key,
    required this.story,
    required this.frame,
    required this.cardOnLeft,
    required this.focused,
    required this.opacity,
    required this.onTap,
    required this.onNode,
    this.originTag,
    required this.onOpenBranch,
  });

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final bool focused;
  final double opacity;
  final VoidCallback onTap;
  final VoidCallback onNode;

  @override
  Widget build(BuildContext context) {
    final year = storyDateLabelFor(story);
    final place = (story.placeLabel ?? '').trim();
    final photos = story.photoCount > 0
        ? countWord(story.photoCount, 'photo', 'photos')
        : null;
    final card = InkWell(
      key: Key('timeline-stub-${story.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        frame.branchesStory
            ? albumCardRadius
            : focused
            ? 12
            : 4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: frame.branchesStory
              ? BoxDecoration(
                  color: albumParchment,
                  borderRadius: BorderRadius.circular(albumCardRadius),
                  border: Border.all(color: branchMoss, width: 1),
                )
              : focused
              ? BoxDecoration(
                  color: albumDialogSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: frame.parent != null ? branchMoss : albumTerracotta,
                    width: 2,
                  ),
                  boxShadow: frame.parent != null
                      ? null
                      : [
                          BoxShadow(
                            color: albumInk.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(
              frame.branchesStory || focused ? calloutCardPadding : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: cardOnLeft
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: cardOnLeft
                      ? WrapAlignment.end
                      : WrapAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? albumTerracotta
                            : albumInk.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        year,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: focused ? albumParchment : albumInk,
                        ),
                      ),
                    ),
                    if (place.isNotEmpty)
                      Text(
                        place,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: focused
                              ? albumTerracotta
                              : albumInk.withValues(alpha: 0.55),
                          fontWeight: focused ? FontWeight.w700 : null,
                        ),
                      ),
                    if (photos != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 14,
                            color: focused
                                ? albumTerracotta
                                : albumInk.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            photos,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (originTag != null)
                  Text(
                    originTag!,
                    key: Key('timeline-origin-tag-${story.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  storyTitle(story),
                  textAlign: cardOnLeft ? TextAlign.end : TextAlign.start,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final mark = Container(
      width: focused ? midDotFocusedDiameter : midDotDiameter,
      height: focused ? midDotFocusedDiameter : midDotDiameter,
      decoration: BoxDecoration(
        color: focused
            ? albumTerracotta.withValues(alpha: 0.22)
            : albumDialogSurface,
        shape: BoxShape.circle,
        border: Border.all(color: albumTerracotta, width: focused ? 2 : 1.5),
      ),
      child: Center(
        child: Container(
          width: focused ? 8 : 6,
          height: focused ? 8 : 6,
          decoration: const BoxDecoration(
            color: albumTerracotta,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    // The branch ring sits just outside the dot. Extra slop belongs only on
    // a plain node, where it cannot cover that stroke.
    Widget nodeHit({required bool slop}) {
      final hit = GestureDetector(
        key: Key('timeline-mid-node-${story.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onNode,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: slop
              ? Padding(padding: const EdgeInsets.all(8), child: mark)
              : mark,
        ),
      );
      // The square bounds cover the ring on the diagonals. Only the disk
      // should open the story.
      return slop ? hit : ClipOval(child: hit);
    }

    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: cardOnLeft ? CalloutSide.left : CalloutSide.right,
            dot: nodeHit(slop: false),
            dotDiameter: focused ? midDotFocusedDiameter : midDotDiameter,
            centerToLane: calloutLaneOffset,
            minCardFromRail: calloutFromRail,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    final pushPad = placed == null
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: cardOnLeft ? 0 : placed.push,
            right: cardOnLeft ? placed.push : 0,
          );
    final parentOverlay = frame.parent == null
        ? null
        : parentCalloutOverlay(
            context: context,
            frame: frame,
            side: cardOnLeft ? CalloutSide.left : CalloutSide.right,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          );
    Widget sideCard(bool show) {
      if (!show) return const SizedBox.shrink();
      final shown = parentOverlay == null
          ? card
          : HangParentCallout(
              anchor: parentOverlay.anchor,
              cardOnLeft: cardOnLeft,
              balance: placed == null,
              callout: parentOverlay.child,
              card: card,
            );
      if (placed == null) return shown;
      return Padding(padding: pushPad, child: shown);
    }

    Widget sideLabel(bool show) {
      if (!show || placed == null) return const SizedBox.shrink();
      return placed.lane;
    }

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Stack(
          alignment: placed == null ? Alignment.center : Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: RailGutter()),
            if (placed == null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: sideCard(cardOnLeft),
                    ),
                  ),
                  const SizedBox(width: calloutGutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: sideCard(!cardOnLeft),
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BranchCalloutTarget(
                    frame: frame,
                    onOpen: onOpenBranch,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: sideLabel(cardOnLeft),
                          ),
                        ),
                        SizedBox(
                          width: calloutGutter,
                          height: calloutHit,
                          child: Center(child: placed.ringHit),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: sideLabel(!cardOnLeft),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: sideCard(cardOnLeft),
                        ),
                      ),
                      const SizedBox(width: calloutGutter),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: sideCard(!cardOnLeft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (placed != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: placed.dot),
              )
            else
              nodeHit(slop: true),
          ],
        ),
      ),
    );
  }
}

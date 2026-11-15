import 'package:flutter/material.dart';

import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'days_attached_callout.dart';
import 'days_card_probe.dart';
import 'days_card_slot.dart';
import 'full_card.dart';
import 'full_card_dot.dart';
import 'timeline_branching.dart';

const _narrowFullDotColumn = 28.0;

class FullCardRow extends StatelessWidget {
  const FullCardRow({
    super.key,
    required this.story,
    required this.frame,
    required this.cardOnLeft,
    required this.wide,
    required this.focused,
    required this.opacity,
    required this.gap,
    required this.photos,
    required this.onOpen,
    this.originTag,
    required this.onOpenBranch,
    this.onPerson,
  });

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final bool wide;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final void Function(({String id, String name}) person)? onPerson;
  final bool focused;
  final double opacity;
  final double gap;
  final PhotosGateway? photos;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (frame.parent == null) return _row(context, null);
    // Same side as the card, matching the days child callout. The 45° run
    // leaves the top center toward that side.
    final side = !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left;
    final overlay = parentCalloutOverlay(
      context: context,
      frame: frame,
      side: side,
      maxLabelWidth: calloutLabelWidthDial,
      onOpen: onOpenBranch,
      fontSize: calloutDaysParentFontSize,
      extraRun: 0,
    );
    return DaysAttachedCallout(
      anchor: overlay.anchor,
      callout: Opacity(opacity: opacity.clamp(0, 1), child: overlay.child),
      body: (slot) => _row(context, slot),
    );
  }

  Widget _row(BuildContext context, DaysCardSlot? slot) {
    final storyCard = FullCard(
      story: story,
      focused: focused,
      branched: frame.branchesStory,
      parentOrigin: frame.parent != null,
      photos: photos,
      originTag: originTag,
      onOpen: onOpen,
      onPerson: onPerson,
    );
    // Narrow rows skip the scale. A 1.05 card overflows the right edge,
    // and focus there is the 20px dot plus the focused card chrome.
    // A branch card and a parent-origin card stay at 1 so focus does not
    // shift them.
    final scale =
        wide && focused && !frame.branchesStory && frame.parent == null
        ? 1.05
        : 1.0;
    final scaled = Transform.scale(scale: scale, child: storyCard);
    final card = Opacity(
      opacity: opacity.clamp(0, 1),
      child: slot == null
          ? scaled
          : DaysCardProbe(slot: slot, scale: scale, child: scaled),
    );
    final dot = FullCardDot(
      key: Key('timeline-full-dot-${story.id}'),
      focused: focused,
      branched: frame.branchesStory,
    );
    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left,
            dot: GestureDetector(onTap: onOpen, child: dot),
            dotDiameter: focused ? fullDotFocusedDiameter : fullDotDiameter,
            centerToLane: wide ? calloutLaneOffset : calloutHit / 2,
            minCardFromRail: wide ? calloutFromRail : null,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    if (placed == null) {
      if (!wide) {
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _narrowFullDotColumn,
                child: Align(alignment: Alignment.center, child: dot),
              ),
              Expanded(child: card),
            ],
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      child: cardOnLeft ? card : const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: calloutGutter),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      child: cardOnLeft ? const SizedBox.shrink() : card,
                    ),
                  ),
                ),
              ],
            ),
            dot,
          ],
        ),
      );
    }
    final pushPad = EdgeInsets.only(
      left: cardOnLeft ? 0 : placed.push,
      right: cardOnLeft ? placed.push : 0,
    );
    if (!wide) {
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                BranchCalloutTarget(
                  frame: frame,
                  onOpen: onOpenBranch,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: calloutHit,
                        height: calloutHit,
                        child: placed.ringHit,
                      ),
                      Expanded(child: placed.lane),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: calloutHit + placed.push),
                  child: card,
                ),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              width: calloutHit,
              height: calloutHit,
              child: Center(child: placed.dot),
            ),
          ],
        ),
      );
    }
    Widget fraction(Widget child) {
      return FractionallySizedBox(widthFactor: 0.92, child: child);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
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
                        child: cardOnLeft
                            ? fraction(placed.lane)
                            : const SizedBox.shrink(),
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
                        child: cardOnLeft
                            ? const SizedBox.shrink()
                            : fraction(placed.lane),
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
                      child: cardOnLeft
                          ? fraction(Padding(padding: pushPad, child: card))
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: calloutGutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: cardOnLeft
                          ? const SizedBox.shrink()
                          : fraction(Padding(padding: pushPad, child: card)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: placed.dot),
          ),
        ],
      ),
    );
  }
}

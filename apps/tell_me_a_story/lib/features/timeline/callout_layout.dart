import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/stories_api.dart';
import 'timeline_zoom.dart';

/// Callout widgets for this layout live in `callout_widgets.dart`.
part 'callout_widgets.dart';

const calloutStroke = 2.0;
const calloutDotGap = 2.0;
const calloutLeaderGap = 2.0;
const calloutLabelGap = 6.0;
const calloutDiagonal = 16.0;

/// Extra 45° run that lifts a years parent callout off the card.
const calloutParentLift = 8.0;

/// Years parent label. Decade callouts stay on the theme's label size.
const calloutParentFontSize = 16.0;

/// Days parent label. Larger than the years parent, under the story title.
const calloutDaysParentFontSize = 20.0;
const calloutStackGap = 4.0;
const calloutHit = 44.0;
const calloutMinRun = 24.0;

/// Years and wide Days keep the card at least this far from the rail center.
const calloutFromRail = 75.0;

/// The side column starts this far from the rail center (half of [calloutGutter]).
const calloutLaneOffset = 28.0;

/// Gutter that holds the rail on Years and wide Days.
const calloutGutter = 56.0;

const calloutLabelWidthFar = 220.0;
const calloutLabelWidthDial = 460.0;

const farDotDiameter = 12.0;
const farDotHighlightedDiameter = 14.0;
const midDotDiameter = 16.0;
const midDotFocusedDiameter = 22.0;
const fullDotDiameter = 14.0;
const fullDotFocusedDiameter = 20.0;

/// Padding inside a Years branch card so the chip and title clear the border.
const calloutCardPadding = 16.0;

final class BranchCallout {
  const BranchCallout._({
    required this.familyId,
    required this.familyName,
    required this.label,
    required this.semanticsLabel,
  });

  final String familyId;
  final String familyName;
  final String label;
  final String semanticsLabel;
}

final class StoryFrame {
  const StoryFrame._({
    required this.story,
    required this.callouts,
    this.parent,
  });

  final Story story;
  final List<BranchCallout> callouts;

  /// Parent timeline of the open family, when [story] is its origin.
  /// Drawn upward, to the right on decades and toward the card on years.
  /// Not a child callout.
  final BranchCallout? parent;

  bool get branchesStory => callouts.isNotEmpty;
}

class _ParentLink {
  const _ParentLink(this.storyId, this.callout);

  final String storyId;
  final BranchCallout callout;
}

final class RailBranching {
  RailBranching._(this._byStory, this._parent);

  final Map<String, List<BranchCallout>> _byStory;
  final _ParentLink? _parent;

  StoryFrame frameFor(Story story) {
    final link = _parent;
    return StoryFrame._(
      story: story,
      callouts: _byStory[story.id] ?? const [],
      parent: link != null && link.storyId == story.id ? link.callout : null,
    );
  }
}

RailBranching railBranching({
  required TreeFamily? open,
  required List<TreeFamily> tree,
  required List<Story> stories,
}) {
  final byStory = <String, List<BranchCallout>>{};
  final family = open;
  final published = <String>{for (final story in stories) story.id};
  if (family != null) {
    for (final row in relatedMarks(tree, family.id)) {
      final childOrigin = row.originStoryId;
      if (row.parentFamilyId != family.id ||
          childOrigin == null ||
          !published.contains(childOrigin)) {
        continue;
      }
      final callout = BranchCallout._(
        familyId: row.id,
        familyName: row.name,
        label: branchMarkLabel(row),
        semanticsLabel: 'Open ${row.name} timeline',
      );
      (byStory[childOrigin] ??= []).add(callout);
    }
  }
  for (final entry in byStory.entries) {
    final calls = [...entry.value]
      ..sort((a, b) {
        final name = a.familyName.toLowerCase().compareTo(
          b.familyName.toLowerCase(),
        );
        if (name != 0) return name;
        return a.familyId.compareTo(b.familyId);
      });
    byStory[entry.key] = List.unmodifiable(calls);
  }
  return RailBranching._(
    byStory,
    _parentLink(family, tree, published, byStory),
  );
}

/// The open family's parent, on its origin story. A parent that is already a
/// child callout on that story is skipped so the two marks do not share a key.
_ParentLink? _parentLink(
  TreeFamily? family,
  List<TreeFamily> tree,
  Set<String> published,
  Map<String, List<BranchCallout>> byStory,
) {
  final parentId = family?.parentFamilyId;
  final originId = family?.originStoryId;
  if (family == null ||
      parentId == null ||
      originId == null ||
      !published.contains(originId)) {
    return null;
  }
  TreeFamily? parentRow;
  for (final row in tree) {
    if (row.id == parentId) {
      parentRow = row;
      break;
    }
  }
  final parent = parentRow;
  if (parent == null) return null;
  final taken =
      byStory[originId]?.any((callout) => callout.familyId == parent.id) ??
      false;
  if (taken) return null;
  final name = parent.name;
  return _ParentLink(
    originId,
    BranchCallout._(
      familyId: parent.id,
      familyName: name,
      label: branchMarkLabel(parent),
      semanticsLabel: 'Open $name timeline',
    ),
  );
}

enum CalloutSide { right, left }

/// [up] leaves the top of the mark and runs upward. Decade parent links use it.
enum CalloutRise { down, up }

class CalloutLeader {
  const CalloutLeader({
    required this.start,
    required this.elbow,
    required this.end,
  });

  final Offset start;
  final Offset elbow;
  final Offset end;
}

class CalloutGeometry {
  const CalloutGeometry({
    required this.ringDiameter,
    required this.leaders,
    required this.labelRects,
    required this.ringHit,
    required this.ringOpensFamily,
    required this.cardTop,
    required this.cardRailEdge,
  });

  final double ringDiameter;
  final List<CalloutLeader> leaders;
  final List<Rect> labelRects;
  final Rect ringHit;
  final bool ringOpensFamily;
  final double cardTop;
  final double cardRailEdge;
}

CalloutGeometry layoutCallouts({
  required CalloutSide side,
  required double dotDiameter,
  required double centerToLane,
  double? minCardFromRail,
  required List<Size> labelSizes,
  CalloutRise rise = CalloutRise.down,
  bool aroundRing = true,
  bool? openRing,
  double extraRun = 0,
}) {
  assert(labelSizes.isNotEmpty);
  final toward = side == CalloutSide.right ? 1.0 : -1.0;
  final vertical = rise == CalloutRise.down ? 1.0 : -1.0;
  final ringDiameter = dotDiameter + 2 * calloutDotGap + 2 * calloutStroke;
  final outerRadius = ringDiameter / 2;
  final attach =
      (aroundRing ? outerRadius : dotDiameter / 2) + calloutLeaderGap;
  final ray = attach / math.sqrt(2);
  // A ring link leaves on the 45° point: lower-right for a child, the
  // matching upper point for a parent. A card link leaves the top center.
  final start = rise == CalloutRise.up && !aroundRing
      ? Offset(0, -attach)
      : Offset(toward * ray, vertical * ray);
  final run = calloutDiagonal + extraRun;
  final elbowX = start.dx + toward * run;
  final minRail = elbowX.abs() + calloutMinRun + calloutLabelGap;
  final rail = math.max(minCardFromRail ?? centerToLane, minRail);
  final leaders = <CalloutLeader>[];
  final rects = <Rect>[];
  var centerY = start.dy + vertical * run;
  for (final size in labelSizes) {
    final top = centerY - size.height / 2;
    final rect = side == CalloutSide.right
        ? Rect.fromLTWH(rail, top, size.width, size.height)
        : Rect.fromLTWH(-rail - size.width, top, size.width, size.height);
    final endX = side == CalloutSide.right
        ? rect.left - calloutLabelGap
        : rect.right + calloutLabelGap;
    leaders.add(
      CalloutLeader(
        start: start,
        elbow: Offset(elbowX, centerY),
        end: Offset(endX, centerY),
      ),
    );
    rects.add(rect);
    centerY += vertical * (math.max(size.height, calloutHit) + calloutStackGap);
  }

  return CalloutGeometry(
    ringDiameter: ringDiameter,
    leaders: List.unmodifiable(leaders),
    labelRects: List.unmodifiable(rects),
    ringHit: Rect.fromCenter(
      center: Offset.zero,
      width: calloutHit,
      height: calloutHit,
    ),
    ringOpensFamily: openRing ?? rects.length == 1,
    cardTop: rise == CalloutRise.down ? rects.last.bottom : rects.last.top,
    cardRailEdge: side == CalloutSide.right
        ? rects.first.left
        : rects.first.right,
  );
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';

void main() {
  test('a direct child on a published origin is that story callout', () {
    const open = TreeFamily(id: 'open', name: 'Open');
    const bea = TreeFamily(
      id: 'bea',
      name: 'Bea',
      parentFamilyId: 'open',
      originStoryId: 's1',
    );
    const ada = TreeFamily(
      id: 'ada',
      name: 'Ada',
      parentFamilyId: 'open',
      originStoryId: 's1',
      branchYear: 1972,
    );
    const sibling = TreeFamily(
      id: 'sib',
      name: 'Sib',
      parentFamilyId: 'other',
      originStoryId: 's1',
    );
    const grandchild = TreeFamily(
      id: 'grand',
      name: 'Grand',
      parentFamilyId: 'bea',
      originStoryId: 's1',
    );
    const missing = TreeFamily(
      id: 'miss',
      name: 'Miss',
      parentFamilyId: 'open',
      originStoryId: 'gone',
    );
    final branching = railBranching(
      open: open,
      tree: const [open, ada, bea, sibling, grandchild, missing],
      stories: [_story('s1'), _story('s2')],
    );

    final frame = branching.frameFor(_story('s1'));
    expect(frame.story.id, 's1');
    expect(frame.branchesStory, isTrue);
    expect(frame.callouts.map((callout) => callout.familyId), ['ada', 'bea']);
    expect(frame.callouts[0].label, 'Ada · 1972');
    expect(frame.callouts[1].label, 'Bea');
    expect(frame.callouts[1].semanticsLabel, 'Open Bea timeline');
    expect(branching.frameFor(_story('s2')).callouts, isEmpty);
    expect(branching.frameFor(_story('s2')).branchesStory, isFalse);
    expect(branchMarkLabel(bea), 'Bea');
    expect(branchMarkLabel(ada), 'Ada · 1972');
  });

  test('same names sort by id', () {
    const open = TreeFamily(id: 'open', name: 'Open');
    final branching = railBranching(
      open: open,
      tree: const [
        open,
        TreeFamily(
          id: 'b',
          name: 'Ann',
          parentFamilyId: 'open',
          originStoryId: 's1',
        ),
        TreeFamily(
          id: 'a',
          name: 'Ann',
          parentFamilyId: 'open',
          originStoryId: 's1',
        ),
      ],
      stories: [_story('s1')],
    );
    expect(
      branching
          .frameFor(_story('s1'))
          .callouts
          .map((callout) => callout.familyId),
      ['a', 'b'],
    );
  });

  test('a parent family is not a child callout', () {
    const parent = TreeFamily(id: 'parent', name: 'Parent', branchYear: 1990);
    const open = TreeFamily(
      id: 'open',
      name: 'Open',
      parentFamilyId: 'parent',
      originStoryId: 's1',
    );
    final onRail = railBranching(
      open: open,
      tree: const [parent, open],
      stories: [_story('s1'), _story('other')],
    );
    final origin = onRail.frameFor(_story('s1'));
    expect(origin.callouts, isEmpty);
    expect(origin.parent?.familyId, 'parent');
    expect(origin.parent?.label, 'Parent');
    expect(origin.parent?.semanticsLabel, 'Open Parent timeline');
    expect(onRail.frameFor(_story('other')).callouts, isEmpty);
    expect(onRail.frameFor(_story('other')).parent, isNull);

    const noOrigin = TreeFamily(
      id: 'open',
      name: 'Open',
      parentFamilyId: 'parent',
    );
    final unmarked = railBranching(
      open: noOrigin,
      tree: const [parent, noOrigin],
      stories: [_story('s1')],
    );
    expect(unmarked.frameFor(_story('s1')).callouts, isEmpty);
    expect(unmarked.frameFor(_story('s1')).parent, isNull);

    const missingOrigin = TreeFamily(
      id: 'open',
      name: 'Open',
      parentFamilyId: 'parent',
      originStoryId: 'missing',
    );
    final missing = railBranching(
      open: missingOrigin,
      tree: const [parent, missingOrigin],
      stories: [_story('s1')],
    );
    expect(missing.frameFor(_story('s1')).callouts, isEmpty);
    expect(missing.frameFor(_story('s1')).parent, isNull);
  });

  test('a parent callout uses the open family branch year', () {
    const parent = TreeFamily(
      id: 'parent',
      name: 'The WFM Morgans',
      branchYear: 1980,
    );
    const open = TreeFamily(
      id: 'open',
      name: 'Open',
      parentFamilyId: 'parent',
      originStoryId: 's1',
      branchYear: 1995,
    );
    final branching = railBranching(
      open: open,
      tree: const [parent, open],
      stories: [_story('s1')],
    );
    final link = branching.frameFor(_story('s1')).parent;
    expect(link?.label, 'The WFM Morgans · 1995');
    expect(link?.familyId, 'parent');
    expect(branching.frameFor(_story('s1')).callouts, isEmpty);

    final missingParent = railBranching(
      open: open,
      tree: const [open],
      stories: [_story('s1')],
    );
    expect(missingParent.frameFor(_story('s1')).parent, isNull);
  });

  test('a parent that also branches from this family is a callout', () {
    const open = TreeFamily(
      id: 'open',
      name: 'Open',
      parentFamilyId: 'p',
      originStoryId: 's1',
    );
    const parent = TreeFamily(
      id: 'p',
      name: 'P',
      parentFamilyId: 'open',
      originStoryId: 's1',
      branchYear: 1972,
    );
    final branching = railBranching(
      open: open,
      tree: const [parent, open],
      stories: [_story('s1')],
    );
    final frame = branching.frameFor(_story('s1'));
    expect(frame.callouts.map((callout) => callout.familyId), ['p']);
    expect(frame.callouts.single.label, 'P · 1972');
    expect(frame.parent, isNull);
  });

  test('the leader starts outside the ring and the left side mirrors', () {
    const dot = 16.0;
    const lane = 160.0;
    const label = Size(80, 20);
    final right = layoutCallouts(
      side: CalloutSide.right,
      dotDiameter: dot,
      centerToLane: lane,
      labelSizes: const [label],
    );
    final outer = right.ringDiameter / 2;
    expect(right.ringDiameter, dot + 2 * calloutDotGap + 2 * calloutStroke);
    final start = right.leaders.single.start;
    expect(
      start.distance,
      greaterThanOrEqualTo(outer + calloutLeaderGap - 0.01),
    );
    expect(start.dx, greaterThan(0));
    expect(start.dy, greaterThan(0));
    expect((start.dx - start.dy).abs(), lessThan(0.01));
    final end = right.leaders.single.end;
    expect(end.dx, greaterThanOrEqualTo(start.dx - 0.01));
    expect(
      right.labelRects.single.left - end.dx,
      closeTo(calloutLabelGap, 0.01),
    );
    expect(end.dy, closeTo(right.labelRects.single.center.dy, 0.01));
    expect(right.ringOpensFamily, isTrue);
    expect(right.ringHit, const Rect.fromLTWH(-22, -22, 44, 44));
    expect(right.cardRailEdge, right.labelRects.single.left);
    expect(right.cardTop, right.labelRects.single.bottom);

    final left = layoutCallouts(
      side: CalloutSide.left,
      dotDiameter: dot,
      centerToLane: lane,
      labelSizes: const [label],
    );
    expect(left.leaders.single.start.dx, closeTo(-start.dx, 0.01));
    expect(left.leaders.single.start.dy, closeTo(start.dy, 0.01));
    expect(
      left.labelRects.single.right,
      closeTo(-right.labelRects.single.left, 0.01),
    );
    expect(
      left.leaders.single.end.dx,
      lessThanOrEqualTo(left.leaders.single.start.dx + 0.01),
    );
    expect(left.cardRailEdge, closeTo(-lane, 0.01));
  });

  test('a short lane still keeps a 24px horizontal run', () {
    for (final lane in [22.0, calloutFromRail]) {
      for (final side in CalloutSide.values) {
        final geometry = layoutCallouts(
          side: side,
          dotDiameter: midDotDiameter,
          centerToLane: lane,
          labelSizes: const [Size(80, 20)],
        );
        final leader = geometry.leaders.single;
        final run = (leader.end.dx - leader.elbow.dx).abs();
        final drop = (leader.elbow.dy - leader.start.dy).abs();
        final diagonal = (leader.elbow.dx - leader.start.dx).abs();
        expect(run, greaterThanOrEqualTo(calloutMinRun - 0.01));
        expect(diagonal, closeTo(drop, 0.01));
        expect(geometry.cardRailEdge.abs(), greaterThanOrEqualTo(lane - 0.01));
        if (lane == calloutFromRail) {
          expect(geometry.cardRailEdge.abs(), closeTo(calloutFromRail, 0.01));
        }
      }
    }
    final seated = layoutCallouts(
      side: CalloutSide.right,
      dotDiameter: midDotDiameter,
      centerToLane: calloutLaneOffset,
      minCardFromRail: calloutFromRail,
      labelSizes: const [Size(80, 20)],
    );
    expect(seated.cardRailEdge, closeTo(calloutFromRail, 0.01));
    expect(
      (seated.leaders.single.end.dx - seated.leaders.single.elbow.dx).abs(),
      greaterThanOrEqualTo(calloutMinRun - 0.01),
    );
  });

  test('two labels stack downward from one leader start', () {
    final geometry = layoutCallouts(
      side: CalloutSide.right,
      dotDiameter: 12,
      centerToLane: 180,
      labelSizes: const [Size(40, 18), Size(70, 30)],
    );
    expect(geometry.ringOpensFamily, isFalse);
    expect(geometry.leaders, hasLength(2));
    expect(geometry.leaders[0].start, geometry.leaders[1].start);
    expect(geometry.labelRects, hasLength(2));
    expect(
      geometry.labelRects[1].top,
      greaterThan(geometry.labelRects[0].bottom),
    );
    expect(
      geometry.labelRects[1].center.dy - geometry.labelRects[0].center.dy,
      closeTo(calloutHit + calloutStackGap, 0.01),
    );
    expect(geometry.cardTop, geometry.labelRects.last.bottom);
    expect(geometry.cardRailEdge, geometry.labelRects.first.left);
  });

  test('an upward ring leader mirrors the child joint onto the top', () {
    const dot = 12.0;
    final down = layoutCallouts(
      side: CalloutSide.right,
      dotDiameter: dot,
      centerToLane: calloutHit / 2,
      labelSizes: const [Size(120, 44)],
    );
    final up = layoutCallouts(
      side: CalloutSide.right,
      dotDiameter: dot,
      centerToLane: calloutHit / 2,
      labelSizes: const [Size(120, 44)],
      rise: CalloutRise.up,
    );
    final child = down.leaders.single;
    final parent = up.leaders.single;
    expect(parent.start.dx, closeTo(child.start.dx, 0.01));
    expect(parent.start.dy, closeTo(-child.start.dy, 0.01));
    expect(parent.start.dx, greaterThan(0));
    expect(parent.start.dy, lessThan(0));
    expect(
      (parent.elbow.dx - parent.start.dx).abs(),
      closeTo((parent.elbow.dy - parent.start.dy).abs(), 0.01),
    );
    expect(parent.elbow.dx, greaterThan(parent.start.dx));
    expect(parent.elbow.dy, lessThan(parent.start.dy));
    expect(
      (parent.elbow.dy - parent.start.dy).abs(),
      closeTo(calloutDiagonal + calloutParentLift, 0.01),
    );
    expect(
      (child.elbow.dy - child.start.dy).abs(),
      closeTo(calloutDiagonal, 0.01),
    );
    expect(parent.end.dy, closeTo(parent.elbow.dy, 0.01));
    expect(parent.end.dx, greaterThan(parent.elbow.dx));
  });

  test('an upward leader leaves the top and runs to the left', () {
    const dot = 12.0;
    const label = Size(120, 44);
    final left = layoutCallouts(
      side: CalloutSide.left,
      dotDiameter: dot,
      centerToLane: calloutHit / 2,
      labelSizes: const [label],
      rise: CalloutRise.up,
      aroundRing: false,
    );
    final start = left.leaders.single.start;
    expect(start.dx, closeTo(0, 0.01));
    expect(start.dy, closeTo(-(dot / 2 + calloutLeaderGap), 0.01));
    final elbow = left.leaders.single.elbow;
    expect(elbow.dx, closeTo(-calloutDiagonal, 0.01));
    expect(elbow.dy, closeTo(start.dy - calloutDiagonal, 0.01));
    expect(elbow.dy, lessThan(start.dy));
    final end = left.leaders.single.end;
    expect(end.dy, closeTo(elbow.dy, 0.01));
    expect(elbow.dx - end.dx, greaterThanOrEqualTo(calloutMinRun - 0.01));
    expect(left.labelRects.single.center.dy, closeTo(end.dy, 0.01));
    expect(left.labelRects.single.right, lessThan(0));
    expect(
      end.dx - left.labelRects.single.right,
      closeTo(calloutLabelGap, 0.01),
    );

    final right = layoutCallouts(
      side: CalloutSide.right,
      dotDiameter: dot,
      centerToLane: calloutHit / 2,
      labelSizes: const [label],
      rise: CalloutRise.up,
      aroundRing: false,
    );
    expect(right.leaders.single.start.dx, closeTo(0, 0.01));
    expect(right.leaders.single.start.dy, closeTo(start.dy, 0.01));
    expect(right.leaders.single.elbow.dx, closeTo(-elbow.dx, 0.01));
    expect(right.labelRects.single.center.dy, closeTo(end.dy, 0.01));
  });
}

Story _story(String id) {
  return Story(
    id: id,
    familyId: 'open',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime(1972),
  );
}

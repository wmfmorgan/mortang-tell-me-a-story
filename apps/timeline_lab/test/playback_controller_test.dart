import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/playback/playback_controller.dart';
import 'package:timeline_lab/playback/playback_schedule.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';

(LabController, PlaybackController) _make(WidgetTester tester) {
  final lab = LabController();
  final pb = PlaybackController(vsync: const TestVSync(), lab: lab);
  addTearDown(() {
    pb.dispose();
    lab.dispose();
  });
  return (lab, pb);
}

void main() {
  testWidgets('idle shows everything; play advances by speed', (tester) async {
    final (lab, pb) = _make(tester);
    final last = lab.entries.last.story.id;
    expect(pb.active, isFalse);
    expect(pb.reveal(last), 1);
    expect(pb.cursorYear, isNull);

    pb.play();
    expect(pb.reveal(last), 0);
    await tester.pump(); // ticker start frame
    await tester.pump(const Duration(seconds: 2));
    expect(pb.clock, closeTo(2, 0.05));

    pb.setSpeed(4);
    await tester.pump(const Duration(seconds: 1));
    expect(pb.clock, closeTo(6, 0.1));

    pb.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(pb.clock, closeTo(6, 0.1));

    pb.stop();
    expect(pb.active, isFalse);
    expect(pb.reveal(last), 1);
  });

  testWidgets('playback stops at the end with everything shown', (
    tester,
  ) async {
    final (lab, pb) = _make(tester);
    pb.setSpeed(4);
    pb.play();
    await tester.pump();
    for (var i = 0; i < 200 && pb.playing; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(pb.playing, isFalse);
    expect(pb.active, isTrue);
    expect(pb.clock, pb.duration);
    expect(pb.revealedCount, lab.entries.length);
    expect(pb.reveal(lab.entries.last.story.id), 1);
  });

  testWidgets('reduced motion makes reveals instant', (tester) async {
    final (lab, pb) = _make(tester);
    final first = lab.entries.first.story.id;
    pb.seek(0.01);
    expect(pb.reveal(first), lessThan(1));
    pb.reducedMotion = true;
    expect(pb.reveal(first), 1);
  });

  testWidgets('steps move one story at a time', (tester) async {
    final (lab, pb) = _make(tester);
    pb.setDesign(PlaybackDesign.steps);
    pb.step(1);
    expect(pb.current!.id, lab.entries[0].story.id);
    pb.step(1);
    pb.step(1);
    expect(pb.current!.id, lab.entries[2].story.id);
    pb.step(-1);
    expect(pb.current!.id, lab.entries[1].story.id);
    expect(pb.revealedCount, 2);
  });

  testWidgets('filter change mid-play keeps the cursor year', (tester) async {
    final (lab, pb) = _make(tester);
    pb.setDesign(PlaybackDesign.sweep);
    pb.seek(pb.duration / 2);
    final year = pb.cursorYear!;
    lab.setFilter(
      const TimelineFilter(personIds: {'p-1'}, mode: FilterMode.hide),
    );
    expect(pb.total, lab.entries.length);
    expect(pb.active, isTrue);
    expect(pb.cursorYear!, closeTo(year, 1e-6));
    // Only stories up to that year are revealed in the new schedule (a
    // same-date burst exactly at the cursor may be part-way through).
    final before = lab.entries.where((e) => e.story.fractionalYear < year);
    final upTo = lab.entries.where((e) => e.story.fractionalYear <= year);
    expect(pb.revealedCount, inInclusiveRange(before.length, upTo.length));
  });

  testWidgets('renderer picks the default design only when idle', (
    tester,
  ) async {
    final (lab, pb) = _make(tester);
    expect(pb.design, PlaybackDesign.steps); // sliver list
    lab.setRenderer(RendererKind.zoomCanvas);
    expect(pb.design, PlaybackDesign.sweep);
    pb.seek(1);
    lab.setRenderer(RendererKind.renderBoxLayout);
    expect(pb.design, PlaybackDesign.sweep);
  });
}

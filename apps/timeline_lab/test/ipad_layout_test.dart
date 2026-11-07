import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';

import 'support/ipad.dart';

/// Sweep cases that overflow until the iPad plan task named in the reason
/// lands. Each fixing task deletes its entries here as its red step.
const _knownRed = <String, String>{};

void main() {
  group('no overflow', () {
    for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
      for (final kind in RendererKind.values) {
        final label = '$name ${kind.name}';
        testWidgets(
          label,
          (tester) async {
            final errors = await collectFlutterErrors(() async {
              await pumpIpad(tester, size, kind: kind);
            });
            expect(errors, isEmpty);
          },
          variant: ios,
          skip: _knownRed.containsKey(label),
        );
      }

      final label = '$name with a selected story';
      testWidgets(
        label,
        (tester) async {
          final errors = await collectFlutterErrors(() async {
            final c = await pumpIpad(tester, size);
            c.select(c.entries.last.story.id);
            await tester.pumpAndSettle();
          });
          expect(errors, isEmpty);
        },
        variant: ios,
        skip: _knownRed.containsKey(label),
      );
    }
  });

  testWidgets('compact playback bar gives the scrubber its own row', (
    tester,
  ) async {
    await pumpIpad(tester, ipadSizes['slide_over']!);
    final bar = tester.getRect(find.byKey(const Key('playback-bar')));
    final scrubber = tester.getRect(find.byKey(const Key('playback-scrubber')));
    expect(scrubber.width, greaterThan(bar.width - 48));
  }, variant: ios);

  testWidgets('selected panel never starves the renderer (Slide Over)', (
    tester,
  ) async {
    final size = ipadSizes['slide_over']!;
    final c = await pumpIpad(tester, size);
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    final panel = tester.getSize(find.byKey(const Key('selected-panel')));
    expect(panel.height, lessThanOrEqualTo(size.height * 0.3 + 1));
    expect(tester.getSize(rendererRoot).height, greaterThan(300));
  }, variant: ios);

  testWidgets('below the sidebar breakpoint filters open in an end drawer', (
    tester,
  ) async {
    final c = await pumpIpad(tester, ipadSizes['mini_portrait']!);
    final before = tester.getSize(rendererRoot);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byKey(const Key('filter-search')), findsNothing);

    await tester.tap(find.byKey(const Key('filters-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filters-drawer')), findsOneWidget);
    expect(tester.getSize(rendererRoot), before); // overlay, no reflow

    await tester.tap(find.byKey(const Key('filter-person-p-1')));
    await tester.pumpAndSettle();
    expect(c.filter.personIds, {'p-1'});
    expect(
      find.descendant(
        of: find.byKey(const Key('filters-drawer')),
        matching: find.text(statusLine(c.matchCount, 120, c.filter)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('filters-close')));
    await tester.pumpAndSettle();
    expect(find.text('Filters · 1'), findsOneWidget);
  }, variant: ios);

  for (final name in [
    'mini_portrait',
    'split_half_wide',
    'split_third',
    'slide_over',
  ]) {
    testWidgets('drawer search works with the keyboard up ($name)', (
      tester,
    ) async {
      final size = ipadSizes[name]!;
      await pumpIpad(tester, size);
      final errors = await collectFlutterErrors(() async {
        await tester.tap(find.byKey(const Key('filters-open')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filter-search')));
        showKeyboard(tester, size);
        await tester.pumpAndSettle();
      });
      expect(errors, isEmpty);
      final field = tester.getRect(find.byKey(const Key('filter-search')));
      expect(
        field.bottom,
        lessThanOrEqualTo(size.height - ipadKeyboardPortrait),
      );
    }, variant: ios);
  }

  testWidgets('keyboard keeps the renderer height (landscape, selected)', (
    tester,
  ) async {
    final size = ipadSizes['mini_landscape']!;
    final c = await pumpIpad(tester, size);
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    final before = tester.getSize(rendererRoot).height;
    final errors = await collectFlutterErrors(() async {
      await tester.tap(find.byKey(const Key('filter-search')));
      showKeyboard(tester, size);
      await tester.pumpAndSettle();
    });
    expect(errors, isEmpty);
    expect(tester.getSize(rendererRoot).height, before);
  }, variant: ios);

  for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
    testWidgets('status bar clears the home indicator ($name)', (tester) async {
      await pumpIpad(tester, size);
      expect(
        tester.getRect(find.byKey(const Key('status-bar'))).bottom,
        lessThanOrEqualTo(size.height - ipadBottomInset),
      );
    }, variant: ios);
  }

  for (final kind in RendererKind.values) {
    testWidgets('rotation mid-playback keeps state (${kind.name})', (
      tester,
    ) async {
      final c = await pumpIpad(tester, ipadSizes['mini_portrait']!, kind: kind);
      c.select(c.entries[c.entries.length ~/ 2].story.id);
      await tester.pumpAndSettle();
      final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
      final renderer = tester.element(rendererRoot);
      pb.play();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final before = pb.clock;
      final errors = await collectFlutterErrors(() async {
        tester.view.physicalSize = ipadSizes['mini_landscape']! * 2;
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      });
      expect(errors, isEmpty);
      expect(pb.playing, isTrue);
      expect(pb.clock, greaterThan(before));
      expect(c.selectedStoryId, isNotNull);
      expect(tester.element(rendererRoot), same(renderer));
      pb.stop();
      await tester.pump();
    }, variant: ios);
  }
}

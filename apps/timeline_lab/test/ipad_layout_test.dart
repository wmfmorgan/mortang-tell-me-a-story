import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';

import 'support/ipad.dart';

/// Sweep cases that overflow until the iPad plan task named in the reason
/// lands. Each fixing task deletes its entries here as its red step.
const _knownRed = <String, String>{
  'split_third sliverList': 'playback bar (ipad Task 4)',
  'split_third renderBoxLayout': 'playback bar (ipad Task 4)',
  'split_third with a selected story':
      'playback bar (ipad Task 4), panel (Task 6)',
  'split_third_wide sliverList': 'playback bar (ipad Task 4)',
  'split_third_wide renderBoxLayout': 'playback bar (ipad Task 4)',
  'split_third_wide with a selected story': 'playback bar (ipad Task 4)',
  'slide_over sliverList': 'playback bar (ipad Task 4)',
  'slide_over renderBoxLayout': 'playback bar (ipad Task 4)',
  'slide_over with a selected story':
      'playback bar (ipad Task 4), panel (Task 6)',
};

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
}

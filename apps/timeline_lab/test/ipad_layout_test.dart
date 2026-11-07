import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';

import 'support/ipad.dart';

void main() {
  group('no overflow', () {
    for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
      for (final kind in RendererKind.values) {
        testWidgets('$name ${kind.name}', (tester) async {
          final errors = await collectFlutterErrors(() async {
            await pumpIpad(tester, size, kind: kind);
          });
          expect(errors, isEmpty);
        }, variant: ios);
      }

      testWidgets('$name with a selected story', (tester) async {
        final errors = await collectFlutterErrors(() async {
          final c = await pumpIpad(tester, size);
          c.select(c.entries.last.story.id);
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty);
      }, variant: ios);
    }
  });
}

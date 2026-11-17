import 'package:flutter_test/flutter_test.dart';

import '../support/lib_line_counts.dart';

/// `throw StateError(` counts. The map only shrinks.
const stateErrorAllowlist = <String, int>{'lib/core/config/env.dart': 3};

void main() {
  test('throw StateError counts match the shrink-only allowlist', () {
    expect(
      libLineCounts(RegExp(r'throw\s+StateError\s*\(')),
      stateErrorAllowlist,
    );
  });

  test('lib/ has no throw ArgumentError of an upper-case code', () {
    final counts = libLineCounts(
      RegExp(r'''throw\s+ArgumentError\(\s*['"][A-Z0-9_]+['"]'''),
    );
    expect(counts, isEmpty);
  });
}

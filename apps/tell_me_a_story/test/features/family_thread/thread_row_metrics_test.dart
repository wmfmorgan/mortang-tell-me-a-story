import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/family_thread/thread_row_metrics.dart';

void main() {
  test('side column is 394 at 944 and 282 at 720', () {
    expect(threadSideColumn(944), 394);
    expect(threadSideColumn(720), 282);
    expect(threadContentColumn(944), 394);
    expect(threadContentColumn(720), 282);
  });

  test('single-side column is 302 at 390', () {
    expect(threadSingleSideColumn(390), 302);
    expect(threadContentColumn(390), 302);
  });

  test('alternating starts at 720 and single-side is below that', () {
    expect(threadLayoutMode(720), ThreadLayoutMode.alternating);
    expect(threadLayoutMode(719), ThreadLayoutMode.singleSide);
  });
}

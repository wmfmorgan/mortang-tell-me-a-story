import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/family_thread/thread_center.dart';

void main() {
  test('nearest on-screen row skips ineligible rows', () {
    final built = [
      (index: 0, centerY: 10.0),
      (index: 1, centerY: 40.0),
      (index: 2, centerY: 70.0),
    ];
    expect(
      nearestOnScreen(
        built: built,
        focusLineY: 42,
        eligible: (index) => index != 1,
      ),
      2,
    );
  });

  test('nearest on-screen row is -1 when nothing is eligible', () {
    expect(
      nearestOnScreen(
        built: [(index: 0, centerY: 10.0)],
        focusLineY: 10,
        eligible: (_) => false,
      ),
      -1,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/ui/timeline/time_axis_painter.dart';
import 'package:tell_me_a_story/ui/timeline/time_scale.dart';

void main() {
  const scale = TimeScale(minYear: 1948, maxYear: 1961, pxPerYear: 10);

  test('decade density keeps only labelled decade ticks', () {
    final marks = timeAxisMarks(scale, finest: TickKind.decade);
    expect(marks.map((m) => m.label), ['1950', '1960']);
    expect(marks.every((m) => m.length == decadeTickLength), isTrue);
  });

  test('year density adds short unlabelled year ticks', () {
    final marks = timeAxisMarks(scale);
    expect(marks, hasLength(1962 - 1948 + 1));
    expect(marks.where((m) => m.label != null).map((m) => m.label), [
      '1950',
      '1960',
    ]);
    expect(
      marks
          .where((m) => m.label == null)
          .every((m) => m.length == yearTickLength),
      isTrue,
    );
  });

  test('labelYears labels every year tick', () {
    expect(
      timeAxisMarks(scale, labelYears: true).every((m) => m.label != null),
      isTrue,
    );
  });

  test('month density adds eleven month ticks per year', () {
    final months = timeAxisMarks(
      scale,
      finest: TickKind.month,
    ).where((m) => m.length == monthTickLength);
    expect(months, hasLength((1961 - 1948 + 1) * 11));
  });
}

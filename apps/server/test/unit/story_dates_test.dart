import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/stories/story_dates.dart';
import 'package:test/test.dart';

Matcher throwsValidation(String message) => throwsA(
  isA<AppException>()
      .having((e) => e.code, 'code', AppErrorCode.validation)
      .having((e) => e.message, 'message', message),
);

void main() {
  group('normalizeStoryDates', () {
    // BR 62
    test('Given no dates, then the draft stays undated', () {
      final d = normalizeStoryDates(null, null, null);
      expect((d.start, d.end, d.precision), (null, null, null));
    });

    // BR 64
    test(
      'Given a start with null end and precision, then end = start and precision day',
      () {
        final d = normalizeStoryDates(DateTime.utc(1950, 6, 3), null, null);
        expect(d.start, DateTime.utc(1950, 6, 3));
        expect(d.end, DateTime.utc(1950, 6, 3));
        expect(d.precision, DatePrecision.day);
      },
    );

    test('Given month and year precision, then the end closes the span', () {
      expect(
        normalizeStoryDates(
          DateTime.utc(1952, 2),
          null,
          DatePrecision.month,
        ).end,
        DateTime.utc(1952, 2, 29),
      );
      expect(
        normalizeStoryDates(
          DateTime.utc(1950),
          DateTime.utc(1950, 12, 31),
          DatePrecision.year,
        ).end,
        DateTime.utc(1950, 12, 31),
      );
    });

    // BR 65
    test(
      'Given day with differing end / month not on 1st / year not full / '
      'year outside 1000–9999 / time of day, then rejected',
      () {
        final bad = <(DateTime, DateTime?, DatePrecision?)>[
          (
            DateTime.utc(1950, 6, 3),
            DateTime.utc(1950, 6, 4),
            DatePrecision.day,
          ),
          (DateTime.utc(1950, 6, 3), DateTime.utc(1950, 6, 9), null),
          (DateTime.utc(1950, 6, 3), null, DatePrecision.month),
          (
            DateTime.utc(1950, 6),
            DateTime.utc(1950, 7, 31),
            DatePrecision.month,
          ),
          (DateTime.utc(1950, 6), null, DatePrecision.year),
          (DateTime.utc(1950), DateTime.utc(1950, 6, 30), DatePrecision.year),
          (DateTime.utc(999), null, DatePrecision.year),
          (DateTime.utc(10000), null, DatePrecision.year),
          (DateTime.utc(1950, 6, 3, 12), null, null),
        ];
        for (final (start, end, precision) in bad) {
          expect(
            () => normalizeStoryDates(start, end, precision),
            throwsValidation(invalidDateMessage),
            reason: '$start $end $precision',
          );
        }
      },
    );

    // BR 66 (decade precision dropped, D9)
    test('Given a decade-wide span, then rejected', () {
      expect(
        () => normalizeStoryDates(
          DateTime.utc(1950),
          DateTime.utc(1959, 12, 31),
          DatePrecision.year,
        ),
        throwsValidation(invalidDateMessage),
      );
    });

    test(
      'Given an end or precision without a start, then VALIDATION "date required"',
      () {
        expect(
          () => normalizeStoryDates(null, DateTime.utc(1950), null),
          throwsValidation('date required'),
        );
        expect(
          () => normalizeStoryDates(null, null, DatePrecision.year),
          throwsValidation('date required'),
        );
      },
    );
  });
}

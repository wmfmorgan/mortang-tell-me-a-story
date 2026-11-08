import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/model/lab_models.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/playback/playback_schedule.dart';

TimelineEntry _e(String id, DateTime start) => TimelineEntry(
  story: LabStory(
    id: id,
    familyId: 'fam-root',
    title: id,
    body: '',
    start: start,
    precision: DatePrecision.day,
    createdAt: DateTime.utc(2025),
    placeId: null,
    personIds: const [],
    photoCount: 0,
  ),
  matched: true,
);

void main() {
  group('sweep', () {
    test('reveal times follow dates and compress long gaps', () {
      final s = PlaybackSchedule.sweep(
        [
          _e('a', DateTime.utc(1950)),
          _e('b', DateTime.utc(1951)),
          _e('c', DateTime.utc(1990)),
        ],
        secondsPerYear: 0.6,
        maxGapSeconds: 1.5,
      );
      expect(s.revealAt[0], 0);
      expect(s.revealAt[1], closeTo(0.6, 1e-9));
      // 39 years would be 23.4 s; compressed to the cap.
      expect(s.revealAt[2], closeTo(2.1, 1e-9));
    });

    test('same-date bursts are staggered and never exceed half a year', () {
      final burst = [
        for (var i = 0; i < 40; i++) _e('s$i', DateTime.utc(1960)),
      ];
      final s = PlaybackSchedule.sweep(burst, secondsPerYear: 0.6);
      for (var i = 1; i < s.revealAt.length; i++) {
        expect(s.revealAt[i], greaterThan(s.revealAt[i - 1]));
      }
      expect(s.revealAt.last, lessThanOrEqualTo(0.3 + 1e-9));
    });

    test('cursor year interpolates and inverts', () {
      final s = PlaybackSchedule.sweep([
        _e('a', DateTime.utc(1950)),
        _e('b', DateTime.utc(1952)),
      ], secondsPerYear: 0.5);
      expect(s.yearAt(0.5), closeTo(1951, 1e-9));
      expect(s.timeForYear(1951), closeTo(0.5, 1e-9));
      expect(s.yearAt(s.timeForYear(1951.5)), closeTo(1951.5, 1e-9));
    });

    test('revealed count and fade', () {
      final s = PlaybackSchedule.sweep(
        [_e('a', DateTime.utc(1950)), _e('b', DateTime.utc(1951))],
        secondsPerYear: 1,
        fade: 0.4,
      );
      expect(s.revealedCount(-0.1), 0);
      expect(s.revealedCount(0), 1);
      expect(s.reveal('b', 0.9, fade: 0.4), 0);
      expect(s.reveal('b', 1.2, fade: 0.4), closeTo(0.5, 1e-9));
      expect(s.reveal('b', 1.0, fade: 0), 1);
      expect(s.reveal('unknown', 0, fade: 0.4), 1);
      expect(s.duration, closeTo(1.4, 1e-9));
    });
  });

  group('steps', () {
    test('uniform dwell per story below the batch threshold', () {
      final d = generateDataset();
      final entries = applyFilter(d, const TimelineFilter());
      final s = PlaybackSchedule.steps(entries, dwell: 1);
      for (var i = 0; i < entries.length; i++) {
        expect(s.revealAt[i], i.toDouble());
      }
      // Cursor sits on the current story, not between stories.
      expect(s.yearAt(5.5), entries[5].story.fractionalYear);
    });

    test('above the threshold a whole year reveals per step', () {
      final d = generateDataset(storyCount: 1000);
      final entries = applyFilter(d, const TimelineFilter());
      final s = PlaybackSchedule.steps(entries, yearDwell: 0.6);
      for (var i = 1; i < entries.length; i++) {
        final sameYear =
            entries[i].story.start.year == entries[i - 1].story.start.year;
        expect(s.revealAt[i] == s.revealAt[i - 1], sameYear);
      }
      final years = entries.map((e) => e.story.start.year).toSet().length;
      expect(s.revealAt.last, closeTo((years - 1) * 0.6, 1e-9));
    });
  });
}

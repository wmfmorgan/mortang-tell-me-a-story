import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/model/lab_models.dart';
import 'package:timeline_lab/model/seed.dart';

LabStory _story(DateTime start, DatePrecision precision) => LabStory(
  id: 's',
  familyId: 'fam-root',
  title: 't',
  body: 'b',
  start: start,
  precision: precision,
  createdAt: DateTime.utc(2025),
  placeId: null,
  personIds: const [],
  photoCount: 0,
);

void main() {
  test('same seed is deterministic; different seed differs', () {
    String sig(LabDataset d) =>
        d.stories.map((s) => '${s.id}|${s.start}|${s.title}').join(';');
    final a = generateDataset(seed: 42);
    final b = generateDataset(seed: 42);
    final c = generateDataset(seed: 7);
    expect(sig(a), sig(b));
    expect(sig(a), isNot(sig(c)));
  });

  test('stories are sorted canonically', () {
    final d = generateDataset(storyCount: 1000);
    for (var i = 1; i < d.stories.length; i++) {
      expect(compareLabStories(d.stories[i - 1], d.stories[i]), lessThan(0));
    }
  });

  test('canonical sort breaks a same-start tie by precision, coarse first', () {
    final day = _story(DateTime.utc(1987, 1, 1), DatePrecision.day);
    final year = _story(DateTime.utc(1987, 1, 1), DatePrecision.year);
    expect(compareLabStories(year, day), lessThan(0));
  });

  test('end follows precision', () {
    expect(
      _story(DateTime.utc(1987), DatePrecision.year).end,
      DateTime.utc(1987, 12, 31),
    );
    expect(
      _story(DateTime.utc(1987, 2), DatePrecision.month).end,
      DateTime.utc(1987, 2, 28),
    );
    expect(
      _story(DateTime.utc(1988, 2), DatePrecision.month).end,
      DateTime.utc(1988, 2, 29),
    );
    expect(
      _story(DateTime.utc(1987, 3, 4), DatePrecision.day).end,
      DateTime.utc(1987, 3, 4),
    );
  });

  test('Dec 31 stays inside its own year, leap or not', () {
    for (final y in [1987, 1988, 2000]) {
      final s = _story(DateTime.utc(y, 12, 31), DatePrecision.day);
      expect(s.fractionalYear, lessThan(y + 1));
      expect(s.fractionalYear, greaterThan(y + 0.99));
    }
  });

  test('date labels are shown as entered', () {
    final d = generateDataset();
    expect(d.dateLabel(_story(DateTime.utc(1987), DatePrecision.year)), '1987');
    expect(
      d.dateLabel(_story(DateTime.utc(1987, 3), DatePrecision.month)),
      'March 1987',
    );
    expect(
      d.dateLabel(_story(DateTime.utc(1987, 3, 4), DatePrecision.day)),
      'March 4, 1987',
    );
  });

  test('branch origins point to a root story at or after the branch year', () {
    final d = generateDataset();
    final branches = d.families.values.where((f) => f.isBranch).toList();
    expect(branches, hasLength(2));
    for (final f in branches) {
      final origin = d.stories.singleWhere((s) => s.id == f.originStoryId);
      expect(origin.familyId, 'fam-root');
      expect(origin.start.year, greaterThanOrEqualTo(f.branchYear!));
      // ...and it is the earliest such story, so the branch starts there.
      final earliest = d.stories.firstWhere(
        (s) => s.familyId == 'fam-root' && s.start.year >= f.branchYear!,
      );
      expect(origin.id, earliest.id);
    }
  });

  test('branch stories never predate their branch year', () {
    final d = generateDataset(storyCount: 1000);
    for (final s in d.stories) {
      final by = d.families[s.familyId]!.branchYear;
      if (by != null) expect(s.start.year, greaterThanOrEqualTo(by));
    }
  });
}

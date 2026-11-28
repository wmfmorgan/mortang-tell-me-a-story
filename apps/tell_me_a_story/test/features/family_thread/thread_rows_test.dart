import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_model.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';
import 'package:tell_me_a_story/features/family_thread/thread_rows.dart';

void main() {
  test('landmark row is 56 before the first beat of each decade in browse and read and never takes focus', () {
    final stories = [
      _story('old', 1982),
      _story('mid', 1994),
      _story('new', 2004),
    ];
    final model = ThreadBeatModel.build(stories);
    expect(threadLandmarkRowExtent, 56);

    for (final density in [
      FamilyThreadDensity.browse,
      FamilyThreadDensity.read,
    ]) {
      final rows = ThreadRows.build(
        model.beatsFor(density),
        density,
        ThreadFilter.cleared,
      );
      expect(_decades(rows), [1980, 1990, 2000]);
      expect(
        rows.rows.whereType<ThreadLandmarkRow>().every(
          (row) => !rows.eligible(rows.rows.indexOf(row)),
        ),
        isTrue,
      );
    }

    final overview = ThreadRows.build(
      model.beatsFor(FamilyThreadDensity.overview),
      FamilyThreadDensity.overview,
      ThreadFilter.cleared,
    );
    expect(overview.rows.whereType<ThreadLandmarkRow>(), isEmpty);
  });

  test('landOn skips a beat the filter rejects', () {
    final model = ThreadBeatModel.build([
      _story('old', 1982),
      _story('mid', 1994),
      _story('new', 2004),
    ]);
    final rows = ThreadRows.build(
      model.beatsFor(FamilyThreadDensity.browse),
      FamilyThreadDensity.browse,
      const ThreadFilter(search: 'new'),
    );
    expect(rows.landOn(0), 2);
    expect(rows.landOn(2), 2);
  });
}

List<int> _decades(ThreadRows rows) {
  final decades = <int>[];
  for (var i = 0; i < rows.rows.length; i++) {
    final row = rows.rows[i];
    if (row is! ThreadLandmarkRow) continue;
    expect(i + 1, lessThan(rows.rows.length));
    expect(rows.rows[i + 1], isA<ThreadBeatRow>());
    decades.add(row.decadeStart);
  }
  return decades;
}

Story _story(String id, int year) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    title: id,
  );
}

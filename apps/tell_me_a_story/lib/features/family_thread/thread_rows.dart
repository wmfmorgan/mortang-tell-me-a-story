import '../../data/family_thread_density.dart';
import 'thread_beat.dart';
import 'thread_beat_model.dart';
import 'thread_filter.dart';

const threadLandmarkRowExtent = 56.0;

sealed class ThreadRow {
  const ThreadRow();
}

final class ThreadLandmarkRow extends ThreadRow {
  const ThreadLandmarkRow(this.decadeStart);

  final int decadeStart;
}

final class ThreadBeatRow extends ThreadRow {
  const ThreadBeatRow({
    required this.beat,
    required this.beatIndex,
    required this.matches,
  });

  final ThreadBeat beat;
  final int beatIndex;
  final bool matches;
}

class ThreadRows {
  const ThreadRows(this.rows, this.beatRow);

  final List<ThreadRow> rows;
  final List<int> beatRow;

  static ThreadRows build(
    List<ThreadBeat> beats,
    FamilyThreadDensity density,
    ThreadFilter filter,
  ) {
    final rows = <ThreadRow>[];
    final beatRow = <int>[];
    final spacers = density != FamilyThreadDensity.overview;
    int? decade;
    for (var i = 0; i < beats.length; i++) {
      final start = _decade(beats[i]);
      if (spacers && start != decade) {
        rows.add(ThreadLandmarkRow(start));
        decade = start;
      }
      beatRow.add(rows.length);
      rows.add(
        ThreadBeatRow(
          beat: beats[i],
          beatIndex: i,
          matches: filter.matchesBeat(beats[i]),
        ),
      );
    }
    return ThreadRows(rows, beatRow);
  }

  int rowOfBeat(int beatIndex) => beatRow[beatIndex];

  bool eligible(int index) {
    final row = rows[index];
    return row is ThreadBeatRow && row.matches;
  }

  /// Nearest matching beat, searching later before earlier. Landmarks are not
  /// beats, so they are never returned.
  int landOn(int beatIndex) {
    if (beatRow.isEmpty) return 0;
    final clamped = beatIndex.clamp(0, beatRow.length - 1);
    if (eligible(beatRow[clamped])) return clamped;
    for (var distance = 1; distance < beatRow.length; distance++) {
      final later = clamped + distance;
      final earlier = clamped - distance;
      if (later < beatRow.length && eligible(beatRow[later])) return later;
      if (earlier >= 0 && eligible(beatRow[earlier])) return earlier;
    }
    return clamped;
  }
}

int _decade(ThreadBeat beat) => switch (beat) {
  DecadeBeat(:final decadeStart) => decadeStart,
  YearBeat(:final year) => threadDecadeOfYear(year),
  StoryBeat(:final story) => threadDecadeOf(story),
};

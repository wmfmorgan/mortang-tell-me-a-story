part of 'thread_beat.dart';

final class DecadeBeat extends ThreadBeat {
  DecadeBeat({required this.decadeStart, required List<Story> stories})
    : stories = List<Story>.unmodifiable(stories);

  final int decadeStart;
  final List<Story> stories;
}

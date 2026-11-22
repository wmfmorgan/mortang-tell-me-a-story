part of 'thread_beat.dart';

final class YearBeat extends ThreadBeat {
  YearBeat({required this.year, required List<Story> stories})
    : stories = List<Story>.unmodifiable(stories);

  final int year;
  final List<Story> stories;
}

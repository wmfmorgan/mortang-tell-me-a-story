import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';

/// A story date: a year, optionally with a month, optionally with a day.
class StoryDate {
  const StoryDate({required this.year, this.month, this.day});

  final int year;
  final int? month;
  final int? day;

  StoryDatePrecision get precision {
    if (month != null && day != null) return StoryDatePrecision.day;
    if (month != null) return StoryDatePrecision.month;
    return StoryDatePrecision.year;
  }

  bool get hasYear => year >= 1000 && year <= 9999;

  static StoryDate fromRow(
    DateTime start,
    DateTime? end,
    StoryDatePrecision precision,
  ) {
    switch (precision) {
      case StoryDatePrecision.year:
        return StoryDate(year: start.year);
      case StoryDatePrecision.month:
        return StoryDate(year: start.year, month: start.month);
      case StoryDatePrecision.day:
        return StoryDate(year: start.year, month: start.month, day: start.day);
    }
  }

  ({DateTime start, DateTime end, StoryDatePrecision precision}) toRange() {
    final kind = precision;
    switch ((month, day)) {
      case (final int m, final int d):
        final date = DateTime(year, m, d);
        return (start: date, end: date, precision: kind);
      case (final int m, _):
        final start = DateTime(year, m, 1);
        final end = DateTime(year, m + 1, 0);
        return (start: start, end: end, precision: kind);
      case _:
        return (
          start: DateTime(year, 1, 1),
          end: DateTime(year, 12, 31),
          precision: kind,
        );
    }
  }
}

const storyMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String storyDateLabel(StoryDate date) {
  switch (date.precision) {
    case StoryDatePrecision.year:
      return '${date.year}';
    case StoryDatePrecision.month:
      return '${storyMonthNames[date.month! - 1]} ${date.year}';
    case StoryDatePrecision.day:
      return '${storyMonthNames[date.month! - 1]} ${date.day}, ${date.year}';
  }
}

String storyDateLabelFor(Story story) {
  return storyDateLabel(
    StoryDate.fromRow(
      story.publishedStart,
      story.timeframeEnd,
      story.datePrecision,
    ),
  );
}

/// Empty or not four digits in 1000–9999. A blank year is not an error yet.
String? storyYearError(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d{4}$').hasMatch(text)) {
    return 'Enter a four-digit year.';
  }
  final year = int.parse(text);
  if (year < 1000 || year > 9999) return 'Enter a four-digit year.';
  return null;
}

int daysInStoryMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String? storyDayError({
  required String yearText,
  required int? month,
  required int? day,
}) {
  if (month == null || day == null) return null;
  if (storyYearError(yearText) != null || yearText.trim().isEmpty) return null;
  final year = int.parse(yearText.trim());
  if (day < 1 || day > daysInStoryMonth(year, month)) {
    return "That day isn't in that month.";
  }
  return null;
}

/// Null until the boxes are a saveable year, month, or day.
StoryDate? storyDateFromFields({
  required String yearText,
  required int? month,
  required int? day,
}) {
  if (storyYearError(yearText) != null) return null;
  final text = yearText.trim();
  if (text.isEmpty) return null;
  final year = int.parse(text);
  if (month != null && day != null) {
    if (storyDayError(yearText: text, month: month, day: day) != null) {
      return null;
    }
    return StoryDate(year: year, month: month, day: day);
  }
  if (month != null) return StoryDate(year: year, month: month);
  return StoryDate(year: year);
}

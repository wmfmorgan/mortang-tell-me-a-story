import '../../data/stories_api.dart';

/// A story date. [legacyDecade] is read from old rows. Capture never writes it.
class StoryDate {
  const StoryDate({
    required this.year,
    this.month,
    this.day,
    this.legacyDecade = false,
  });

  final int year;
  final int? month;
  final int? day;
  final bool legacyDecade;

  StoryDatePrecision get precision {
    if (legacyDecade) return StoryDatePrecision.decade;
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
      case StoryDatePrecision.decade:
        return StoryDate(year: start.year, legacyDecade: true);
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
    switch (kind) {
      case StoryDatePrecision.day:
        final date = DateTime(year, month!, day!);
        return (start: date, end: date, precision: kind);
      case StoryDatePrecision.month:
        final start = DateTime(year, month!, 1);
        final end = DateTime(year, month! + 1, 0);
        return (start: start, end: end, precision: kind);
      case StoryDatePrecision.year:
        return (
          start: DateTime(year, 1, 1),
          end: DateTime(year, 12, 31),
          precision: kind,
        );
      case StoryDatePrecision.decade:
        final startYear = year - (year % 10);
        return (
          start: DateTime(startYear, 1, 1),
          end: DateTime(startYear + 9, 12, 31),
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
    case StoryDatePrecision.decade:
      final start = date.year - (date.year % 10);
      return '${start}s';
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

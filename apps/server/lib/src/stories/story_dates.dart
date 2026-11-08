import '../errors.dart';
import '../generated/protocol.dart';

/// A date span the timeline can't store (business-rules §4.4, CHECK
/// `stories_date_shape`). §5.2 has no catalogue string for it; the old app
/// surfaced the raw CHECK failure as "Try again".
const invalidDateMessage = 'invalid date';

/// A story's stored dates: all null (undated draft) or a full span.
typedef StoryDates = ({
  DateTime? start,
  DateTime? end,
  DatePrecision? precision,
});

/// Normalizes client dates to the stored shape (business-rules §4.4):
/// - no start: undated; an end or a precision alone is `date required`;
/// - no precision: `day` when the end is missing or equals the start;
/// - the end is derived from start + precision (schema-design §0.5), and a
///   client end that differs is refused;
/// - the start is UTC midnight, aligned to its precision, in 1000–9999.
StoryDates normalizeStoryDates(
  DateTime? start,
  DateTime? end,
  DatePrecision? precision,
) {
  if (start == null) {
    if (end != null || precision != null) throw validation('date required');
    return (start: null, end: null, precision: null);
  }
  final from = _calendarDay(start);
  final to = end == null ? null : _calendarDay(end);
  final p =
      precision ??
      (to == null || to == from
          ? DatePrecision.day
          : throw validation(invalidDateMessage));
  if (from.year < 1000 || from.year > 9999) {
    throw validation(invalidDateMessage);
  }
  final derivedEnd = switch (p) {
    DatePrecision.day => from,
    DatePrecision.month when from.day == 1 => DateTime.utc(
      from.year,
      from.month + 1,
      0,
    ),
    DatePrecision.year when from.month == 1 && from.day == 1 => DateTime.utc(
      from.year,
      12,
      31,
    ),
    _ => throw validation(invalidDateMessage),
  };
  if (to != null && to != derivedEnd) throw validation(invalidDateMessage);
  return (start: from, end: derivedEnd, precision: p);
}

/// [value] as a UTC calendar day; a time of day is refused.
DateTime _calendarDay(DateTime value) {
  final utc = value.toUtc();
  final day = DateTime.utc(utc.year, utc.month, utc.day);
  if (utc != day) throw validation(invalidDateMessage);
  return day;
}

/// Coarse to fine, like the server's `DatePrecision`; timeline order sorts
/// on it. `decade` was dropped (D9).
enum StoryDatePrecision { year, month, day }

StoryDatePrecision storyDatePrecisionFrom(String? raw) {
  for (final value in StoryDatePrecision.values) {
    if (value.name == raw) return value;
  }
  return StoryDatePrecision.day;
}

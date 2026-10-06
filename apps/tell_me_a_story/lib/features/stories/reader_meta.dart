const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Jul 24, 1974`. Local calendar date.
String albumDate(DateTime value) {
  final local = value.toLocal();
  return '${_monthShort[local.month - 1]} ${local.day}, ${local.year}';
}

/// `Oct 2023`. Local calendar month.
String albumMonthYear(DateTime value) {
  final local = value.toLocal();
  return '${_monthShort[local.month - 1]} ${local.year}';
}

/// Recorded event. A different end date joins with an en dash.
String recordedEventLabel({required DateTime start, DateTime? end}) {
  final startLabel = albumDate(start);
  if (end == null || _sameDay(start, end)) return startLabel;
  return '$startLabel – ${albumDate(end)}';
}

/// Decade from the start year. 1974 is `1970s`.
String decadeChipLabel(DateTime start) {
  final decade = (start.year ~/ 10) * 10;
  return '${decade}s';
}

/// Ceil(words / 200), minimum 1. Nothing is stored.
int minutesToRead(String? body) {
  final words = (body ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
  final minutes = (words / 200).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// Place chip. Label wins. Address is the fallback. Blank means no chip.
String? placeChipText({required String label, required String address}) {
  final trimmed = label.trim();
  if (trimmed.isNotEmpty) return trimmed;
  final fallback = address.trim();
  if (fallback.isEmpty) return null;
  return fallback;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

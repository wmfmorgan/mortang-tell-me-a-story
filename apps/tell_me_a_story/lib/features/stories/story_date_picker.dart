import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_theme.dart';
import 'story_date.dart';

/// Year, month, and day boxes. Precision comes from whichever boxes are filled.
class StoryDatePicker extends StatelessWidget {
  const StoryDatePicker({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.onMonth,
    required this.onDay,
    required this.onYearChanged,
  });

  final TextEditingController year;
  final int? month;
  final int? day;
  final ValueChanged<int?> onMonth;
  final ValueChanged<int?> onDay;
  final VoidCallback onYearChanged;

  @override
  Widget build(BuildContext context) {
    final yearError = storyYearError(year.text);
    final dayError = storyDayError(
      yearText: year.text,
      month: month,
      day: day,
    );
    final date = storyDateFromFields(
      yearText: year.text,
      month: month,
      day: day,
    );
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: albumInk.withValues(alpha: 0.7),
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _box(
                label: 'Year',
                labelStyle: labelStyle,
                child: TextField(
                  key: const Key('story-date-year'),
                  controller: year,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '1987',
                    errorText: yearError,
                  ),
                  onChanged: (_) => onYearChanged(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _box(
                label: 'Month',
                labelStyle: labelStyle,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        key: const Key('story-date-month'),
                        value: month,
                        isExpanded: true,
                        hint: const Text('Month'),
                        underline: const SizedBox.shrink(),
                        items: [
                          for (var i = 0; i < storyMonthNames.length; i++)
                            DropdownMenuItem(
                              value: i + 1,
                              child: Text(
                                storyMonthNames[i],
                                textAlign: TextAlign.left,
                              ),
                            ),
                        ],
                        onChanged: onMonth,
                      ),
                    ),
                    if (month != null)
                      IconButton(
                        key: const Key('story-date-clear-month'),
                        tooltip: 'Clear month',
                        onPressed: () => onMonth(null),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _box(
                label: 'Day',
                labelStyle: labelStyle,
                child: DropdownButton<int>(
                  key: const Key('story-date-day'),
                  value: day != null && day! >= 1 && day! <= 31 ? day : null,
                  isExpanded: true,
                  hint: const Text('Day'),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (var i = 1; i <= 31; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('$i', textAlign: TextAlign.left),
                      ),
                  ],
                  onChanged: month == null ? null : onDay,
                ),
              ),
            ),
          ],
        ),
        if (dayError != null) ...[
          const SizedBox(height: 4),
          Text(
            dayError,
            key: const Key('story-date-day-error'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: albumTerracotta,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Year is required. Add the month or day only if you remember. Day unlocks after Month.',
          key: const Key('story-date-helper'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: albumInk.withValues(alpha: 0.62),
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: 6),
          Text(
            'Shows as: ${storyDateLabel(date)}',
            key: const Key('story-date-preview'),
          ),
        ],
      ],
    );
  }

  Widget _box({
    required String label,
    required TextStyle? labelStyle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

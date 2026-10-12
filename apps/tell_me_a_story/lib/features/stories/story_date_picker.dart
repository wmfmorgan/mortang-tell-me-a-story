import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import 'story_date.dart';

const _dateFill = Color(0xFFFAF2F0);
const _dateOutline = Color(0xFF817976);
const _dateMuted = Color(0xFF655E5B);

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
    final dayError = storyDayError(yearText: year.text, month: month, day: day);
    final date = storyDateFromFields(
      yearText: year.text,
      month: month,
      day: day,
    );
    final labelStyle = GoogleFonts.sourceSans3(
      color: _dateMuted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );
    final valueStyle = GoogleFonts.literata(
      color: albumInk,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _box(
                label: 'YEAR',
                labelStyle: labelStyle,
                child: TextField(
                  key: const Key('story-date-year'),
                  controller: year,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '1987',
                    hintStyle: valueStyle.copyWith(
                      color: _dateOutline.withValues(alpha: 0.7),
                    ),
                    errorText: yearError,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => onYearChanged(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _box(
                label: 'MONTH',
                labelStyle: labelStyle,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        key: const Key('story-date-month'),
                        value: month,
                        isExpanded: true,
                        alignment: Alignment.centerLeft,
                        hint: Text('Month', style: valueStyle),
                        style: valueStyle,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(
                          Icons.expand_more,
                          color: _dateMuted,
                          size: 20,
                        ),
                        items: [
                          for (var i = 0; i < storyMonthNames.length; i++)
                            DropdownMenuItem(
                              value: i + 1,
                              child: Text(
                                storyMonthNames[i],
                                style: valueStyle,
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
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => onMonth(null),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _box(
                label: 'DAY',
                labelStyle: labelStyle,
                child: DropdownButton<int>(
                  key: const Key('story-date-day'),
                  value: day != null && day! >= 1 && day! <= 31 ? day : null,
                  isExpanded: true,
                  alignment: Alignment.center,
                  hint: Text('Day', style: valueStyle),
                  style: valueStyle,
                  underline: const SizedBox.shrink(),
                  icon: const SizedBox.shrink(),
                  items: [
                    for (var i = 1; i <= 31; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '$i',
                          textAlign: TextAlign.center,
                          style: valueStyle,
                        ),
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
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: albumTerracotta),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Year is required. Add the month or day only if you remember. Day unlocks after Month.',
          key: const Key('story-date-helper'),
          style: GoogleFonts.literata(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: _dateMuted.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _dateOutline.withValues(alpha: 0.2)),
              ),
            ),
            child: Text(
              'Shows as: ${storyDateLabel(date)}',
              key: const Key('story-date-preview'),
              style: GoogleFonts.newsreader(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: albumSage,
              ),
            ),
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
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _dateFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _dateOutline.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        ),
      ],
    );
  }
}

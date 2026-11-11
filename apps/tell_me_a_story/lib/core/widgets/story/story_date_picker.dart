import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';

const _dateFill = albumParchment;
const _dateOutline = albumSage;
const _dateMuted = albumInk;

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
    this.enabled = true,
    this.showHelper = true,
  });

  final TextEditingController year;
  final int? month;
  final int? day;
  final bool enabled;
  final bool showHelper;
  final ValueChanged<int?> onMonth;
  final ValueChanged<int?> onDay;
  final VoidCallback onYearChanged;

  @override
  Widget build(BuildContext context) {
    final dayError = storyDayError(yearText: year.text, month: month, day: day);
    final date = storyDateFromFields(
      yearText: year.text,
      month: month,
      day: day,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateFields(picker: this),
        if (dayError != null) ...[
          const SizedBox(height: 4),
          Text(
            dayError,
            key: const Key('story-date-day-error'),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: albumTerracotta),
          ),
        ],
        if (showHelper) ...[const SizedBox(height: 12), const _DateHelper()],
        if (date != null) ...[
          const SizedBox(height: 16),
          _DatePreview(date: date),
        ],
      ],
    );
  }
}

class _DateFields extends StatelessWidget {
  const _DateFields({required this.picker});

  final StoryDatePicker picker;

  @override
  Widget build(BuildContext context) {
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DateBox(
            label: 'YEAR',
            labelStyle: labelStyle,
            child: _YearField(picker: picker, valueStyle: valueStyle),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _DateBox(
            label: 'MONTH',
            labelStyle: labelStyle,
            child: _MonthField(picker: picker, valueStyle: valueStyle),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _DateBox(
            label: 'DAY',
            labelStyle: labelStyle,
            child: _DayField(picker: picker, valueStyle: valueStyle),
          ),
        ),
      ],
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({required this.picker, required this.valueStyle});

  final StoryDatePicker picker;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('story-date-year'),
      controller: picker.year,
      enabled: picker.enabled,
      textAlign: TextAlign.left,
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
        errorText: storyYearError(picker.year.text),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onChanged: (_) => picker.onYearChanged(),
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({required this.picker, required this.valueStyle});

  final StoryDatePicker picker;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = picker.enabled;
    return Row(
      children: [
        Expanded(
          child: DropdownButton<int>(
            key: const Key('story-date-month'),
            value: picker.month,
            isExpanded: true,
            alignment: Alignment.centerLeft,
            hint: Text('Month', style: valueStyle),
            style: valueStyle,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.expand_more, color: _dateMuted, size: 20),
            items: [
              for (var i = 0; i < storyMonthNames.length; i++)
                DropdownMenuItem(
                  value: i + 1,
                  child: Text(storyMonthNames[i], style: valueStyle),
                ),
            ],
            onChanged: enabled ? picker.onMonth : null,
          ),
        ),
        if (picker.month != null)
          IconButton(
            key: const Key('story-date-clear-month'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: enabled ? () => picker.onMonth(null) : null,
            icon: const Icon(Icons.close, size: 16),
          ),
      ],
    );
  }
}

class _DayField extends StatelessWidget {
  const _DayField({required this.picker, required this.valueStyle});

  final StoryDatePicker picker;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    final day = picker.day;
    return DropdownButton<int>(
      key: const Key('story-date-day'),
      value: day != null && day >= 1 && day <= 31 ? day : null,
      isExpanded: true,
      alignment: Alignment.centerLeft,
      hint: Text('Day', style: valueStyle),
      style: valueStyle,
      underline: const SizedBox.shrink(),
      icon: const SizedBox.shrink(),
      items: [
        for (var i = 1; i <= 31; i++)
          DropdownMenuItem(
            value: i,
            child: Text('$i', textAlign: TextAlign.left, style: valueStyle),
          ),
      ],
      onChanged: !picker.enabled || picker.month == null ? null : picker.onDay,
    );
  }
}

class _DateHelper extends StatelessWidget {
  const _DateHelper();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Year is required. Add the month or day only if you remember. Day unlocks after Month.',
      key: const Key('story-date-helper'),
      style: GoogleFonts.literata(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: _dateMuted.withValues(alpha: 0.8),
        height: 1.4,
      ),
    );
  }
}

class _DatePreview extends StatelessWidget {
  const _DatePreview({required this.date});

  final StoryDate date;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.labelStyle,
    required this.child,
  });

  final String label;
  final TextStyle? labelStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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

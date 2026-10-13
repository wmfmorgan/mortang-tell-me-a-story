import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import '../stories/story_date_picker.dart';

/// Date of birth or date of passing. Reuses the story year, month, and day boxes.
class PersonDateField extends StatefulWidget {
  const PersonDateField({
    super.key,
    required this.label,
    this.initial,
    required this.onChanged,
    this.framed = false,
    this.showLabel = true,
    this.icon,
    this.iconColor,
  });

  final String label;
  final StoryDate? initial;
  final ValueChanged<StoryDate?> onChanged;

  /// Parchment card used by Add person. Edit person keeps the plain label.
  final bool framed;

  /// Settings draws its own date heading and hides this one.
  final bool showLabel;
  final IconData? icon;
  final Color? iconColor;

  @override
  State<PersonDateField> createState() => _PersonDateFieldState();
}

class _PersonDateFieldState extends State<PersonDateField> {
  late final TextEditingController _year;
  int? _month;
  int? _day;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _year = TextEditingController(
      text: initial == null ? '' : '${initial.year}',
    );
    _month = initial?.month;
    _day = initial?.day;
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      storyDateFromFields(yearText: _year.text, month: _month, day: _day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picker = StoryDatePicker(
      year: _year,
      month: _month,
      day: _day,
      onMonth: (month) {
        setState(() => _month = month);
        _emit();
      },
      onDay: (day) {
        setState(() => _day = day);
        _emit();
      },
      onYearChanged: () {
        setState(_emit);
      },
    );
    if (!widget.framed) {
      if (!widget.showLabel) return picker;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          picker,
        ],
      );
    }
    final muted = albumInk.withValues(alpha: 0.55);
    final kicker = Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: muted,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 15,
                        color: widget.iconColor ?? albumSage,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(widget.label.toUpperCase(), style: kicker),
                    const SizedBox(width: 6),
                    Text(
                      '(optional)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumInk.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  'May be left blank',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: albumInk.withValues(alpha: 0.45),
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            picker,
          ],
        ),
      ),
    );
  }
}

StoryDate? storyDateFromPerson(DateTime? date, String? precision) {
  if (date == null || precision == null) return null;
  return StoryDate.fromRow(date, null, storyDatePrecisionFrom(precision));
}

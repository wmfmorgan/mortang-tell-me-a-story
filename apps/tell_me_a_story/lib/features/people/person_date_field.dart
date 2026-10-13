import 'package:flutter/material.dart';

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
  });

  final String label;
  final StoryDate? initial;
  final ValueChanged<StoryDate?> onChanged;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        StoryDatePicker(
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
        ),
      ],
    );
  }
}

StoryDate? storyDateFromPerson(DateTime? date, String? precision) {
  if (date == null || precision == null) return null;
  return StoryDate.fromRow(date, null, storyDatePrecisionFrom(precision));
}

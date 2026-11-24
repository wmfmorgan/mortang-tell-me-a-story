import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'thread_beat_model.dart';
import 'thread_filter.dart';

class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.filter,
    required this.stories,
    required this.personLabels,
    required this.placeLabels,
    required this.onChanged,
    this.countLabel,
    this.onClose,
  });

  final ThreadFilter filter;
  final List<Story> stories;
  final Map<String, String> personLabels;
  final Map<String, String> placeLabels;
  final ValueChanged<ThreadFilter> onChanged;
  final String? countLabel;
  final VoidCallback? onClose;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.search,
  );

  @override
  void didUpdateWidget(FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final search = widget.filter.search;
    if (_search.text == search) return;
    _search.value = TextEditingValue(
      text: search,
      selection: TextSelection.collapsed(offset: search.length),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterHeader(countLabel: widget.countLabel, onClose: widget.onClose),
        Expanded(child: _sections()),
      ],
    );
  }

  Widget _sections() {
    final span = _decadeSpan(widget.stories);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _searchField(),
        _ChipGroup(
          title: FamilyThreadCopy.people,
          labels: widget.personLabels,
          selected: widget.filter.personIds,
          onTap: _togglePerson,
        ),
        _ChipGroup(
          title: FamilyThreadCopy.places,
          labels: widget.placeLabels,
          selected: widget.filter.placeIds,
          onTap: _togglePlace,
        ),
        if (span != null)
          _Years(
            filter: widget.filter,
            span: span,
            onChanged: widget.onChanged,
          ),
        _clearButton(),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      decoration: const InputDecoration(hintText: FamilyThreadCopy.searchHint),
      onChanged: (value) {
        widget.onChanged(widget.filter.copyWith(search: value));
      },
    );
  }

  Widget _clearButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => widget.onChanged(ThreadFilter.cleared),
        style: TextButton.styleFrom(
          foregroundColor: albumTerracotta,
          minimumSize: const Size(44, 44),
        ),
        child: const Text(FamilyThreadCopy.clearFilters),
      ),
    );
  }

  void _togglePerson(String id) {
    final filter = widget.filter;
    widget.onChanged(
      filter.personIds.contains(id)
          ? filter.withoutPerson(id)
          : filter.withPerson(id),
    );
  }

  void _togglePlace(String id) {
    final filter = widget.filter;
    widget.onChanged(
      filter.placeIds.contains(id)
          ? filter.withoutPlace(id)
          : filter.withPlace(id),
    );
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({required this.countLabel, required this.onClose});

  final String? countLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
      child: Row(
        children: [
          Text(
            FamilyThreadCopy.filters,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (countLabel != null) ...[
            const SizedBox(width: 8),
            Text(countLabel!, style: Theme.of(context).textTheme.labelLarge),
          ],
          const Spacer(),
          if (onClose != null)
            IconButton(
              tooltip: FamilyThreadCopy.closeFilters,
              onPressed: onClose,
              icon: const Icon(Icons.close, color: albumInk),
            ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final Map<String, String> labels;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in _sortedIds(labels))
                _ChoiceChip(
                  id: id,
                  label: labels[id] ?? id,
                  selected: selected.contains(id),
                  onTap: () => onTap(id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('filter-choice-$id'),
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? sageTint : albumPillFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: albumPillBorder),
        ),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ChoiceLabel(label: label, selected: selected),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceLabel extends StatelessWidget {
  const _ChoiceLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: albumInk),
        ),
        if (selected) ...[
          const SizedBox(width: 4),
          const Icon(Icons.check, size: 16, color: albumInk),
        ],
      ],
    );
  }
}

class _Years extends StatelessWidget {
  const _Years({
    required this.filter,
    required this.span,
    required this.onChanged,
  });

  final ThreadFilter filter;
  final ({int min, int max}) span;
  final ValueChanged<ThreadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final start = _edge(filter.decadeFrom, span.min);
    final end = _edge(filter.decadeTo, span.max);
    final from = start <= end ? start : end;
    final to = start <= end ? end : start;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FamilyThreadCopy.years,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(FamilyThreadCopy.decadeRange(from, to)),
          if (span.max > span.min) _slider(from, to),
        ],
      ),
    );
  }

  Widget _slider(int from, int to) {
    return RangeSlider(
      values: RangeValues(from.toDouble(), to.toDouble()),
      min: span.min.toDouble(),
      max: span.max.toDouble(),
      divisions: (span.max - span.min) ~/ 10,
      onChanged: (values) => onChanged(_next(values)),
    );
  }

  int _edge(int? value, int fallback) {
    final decade = value ?? fallback;
    if (decade < span.min) return span.min;
    if (decade > span.max) return span.max;
    return decade;
  }

  ThreadFilter _next(RangeValues values) {
    final from = values.start.round();
    final to = values.end.round();
    if (from <= span.min && to >= span.max) {
      return filter.copyWith(clearDecade: true);
    }
    return filter.copyWith(decadeFrom: from, decadeTo: to);
  }
}

List<String> _sortedIds(Map<String, String> labels) {
  final ids = [...labels.keys];
  ids.sort((a, b) {
    final byLabel = (labels[a] ?? a).compareTo(labels[b] ?? b);
    if (byLabel != 0) return byLabel;
    return a.compareTo(b);
  });
  return ids;
}

({int min, int max})? _decadeSpan(List<Story> stories) {
  int? minDecade;
  int? maxDecade;
  for (final story in stories) {
    final decade = threadDecadeOf(story);
    if (minDecade == null || decade < minDecade) minDecade = decade;
    if (maxDecade == null || decade > maxDecade) maxDecade = decade;
  }
  if (minDecade == null || maxDecade == null) return null;
  return (min: minDecade, max: maxDecade);
}

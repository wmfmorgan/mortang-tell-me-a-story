import 'package:flutter/material.dart';

import 'timeline_v2_filter.dart';
import 'timeline_v2_filter_options.dart';

/// Search, people, places, and a decade range. The page owns [filter].
class TimelineV2FilterPanel extends StatefulWidget {
  const TimelineV2FilterPanel({
    super.key,
    required this.filter,
    required this.options,
    required this.matched,
    required this.total,
    required this.onChanged,
  });

  final TimelineV2Filter filter;
  final TimelineV2FilterOptions options;
  final int matched;
  final int total;
  final ValueChanged<TimelineV2Filter> onChanged;

  @override
  State<TimelineV2FilterPanel> createState() => _TimelineV2FilterPanelState();
}

class _TimelineV2FilterPanelState extends State<TimelineV2FilterPanel> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.filter.query);
  }

  @override
  void didUpdateWidget(covariant TimelineV2FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.filter.query;
    if (_search.text != query) _search.text = query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Filters', style: Theme.of(context).textTheme.titleLarge),
        if (filter.isActive) _status(),
        const SizedBox(height: 12),
        _queryField(filter),
        if (widget.options.people.isNotEmpty) _people(filter),
        if (widget.options.places.isNotEmpty) _places(filter),
        if (widget.options.decades.length > 1)
          _DecadeRange(
            decades: widget.options.decades,
            filter: filter,
            onChanged: widget.onChanged,
          ),
        if (filter.isActive) _clear(),
      ],
    );
  }

  Widget _status() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        TimelineV2Filter.statusLine(widget.matched, widget.total),
        key: const Key('timeline-v2-filter-status'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _queryField(TimelineV2Filter filter) {
    return TextField(
      key: const Key('timeline-v2-filter-search'),
      controller: _search,
      decoration: const InputDecoration(
        hintText: 'Search titles, stories and people',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (query) => widget.onChanged(filter.copyWith(query: query)),
    );
  }

  Widget _people(TimelineV2Filter filter) {
    return _ChipBlock(
      title: 'People',
      children: [
        for (final person in widget.options.people)
          _choice(
            key: Key('timeline-v2-filter-person-${person.id}'),
            label: person.name,
            selected: filter.personIds.contains(person.id),
            onSelected: (on) => widget.onChanged(
              filter.copyWith(
                personIds: _toggled(filter.personIds, person.id, on),
              ),
            ),
          ),
      ],
    );
  }

  Widget _places(TimelineV2Filter filter) {
    return _ChipBlock(
      title: 'Places',
      children: [
        for (final place in widget.options.places)
          _choice(
            key: Key('timeline-v2-filter-place-${place.id}'),
            label: place.label,
            selected: filter.placeIds.contains(place.id),
            onSelected: (on) => widget.onChanged(
              filter.copyWith(
                placeIds: _toggled(filter.placeIds, place.id, on),
              ),
            ),
          ),
      ],
    );
  }

  Widget _clear() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: const Key('timeline-v2-filter-clear'),
        onPressed: () => widget.onChanged(const TimelineV2Filter()),
        child: const Text('Clear filters'),
      ),
    );
  }

  Widget _choice({
    required Key key,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      key: key,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

Set<String> _toggled(Set<String> ids, String id, bool on) {
  final next = {...ids};
  if (on) {
    next.add(id);
  } else {
    next.remove(id);
  }
  return next;
}

class _ChipBlock extends StatelessWidget {
  const _ChipBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _DecadeRange extends StatelessWidget {
  const _DecadeRange({
    required this.decades,
    required this.filter,
    required this.onChanged,
  });

  final List<int> decades;
  final TimelineV2Filter filter;
  final ValueChanged<TimelineV2Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final last = decades.length - 1;
    final from = _indexOf(filter.fromDecade, decades, fallback: 0);
    final to = _endIndex(filter.toDecade, decades, from);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Years', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '${decades[from]}s – ${decades[to]}s',
            key: const Key('timeline-v2-filter-decades-label'),
          ),
          RangeSlider(
            key: const Key('timeline-v2-filter-decades'),
            min: 0,
            max: last.toDouble(),
            divisions: last,
            values: RangeValues(from.toDouble(), to.toDouble()),
            labels: RangeLabels('${decades[from]}s', '${decades[to]}s'),
            onChanged: (range) => onChanged(_ranged(range, last)),
          ),
        ],
      ),
    );
  }

  TimelineV2Filter _ranged(RangeValues range, int last) {
    final start = range.start.round();
    final end = range.end.round();
    return filter.copyWith(
      fromDecade: () => start == 0 ? null : decades[start],
      toDecade: () => end == last ? null : decades[end],
    );
  }
}

int _indexOf(int? decade, List<int> decades, {required int fallback}) {
  if (decade == null) return fallback;
  final at = decades.indexWhere((row) => row >= decade);
  return at < 0 ? decades.length - 1 : at;
}

int _endIndex(int? decade, List<int> decades, int from) {
  final last = decades.length - 1;
  if (decade == null) return last;
  final at = decades.lastIndexWhere((row) => row <= decade);
  if (at < from) return from;
  if (at > last) return last;
  return at;
}

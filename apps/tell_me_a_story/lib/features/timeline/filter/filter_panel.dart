import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/filter/timeline_filter.dart';

/// The timeline filters (Q4, copy C11–C17): a search field, People, Places
/// and a decade range. Every control reports a new [TimelineFilter] through
/// [onChanged]; the page owns the state, so the sidebar and the drawer show
/// the same filter.
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.filter,
    required this.options,
    required this.matched,
    required this.total,
    required this.onChanged,
  });

  final TimelineFilter filter;
  final FilterOptions options;
  final int matched;
  final int total;
  final ValueChanged<TimelineFilter> onChanged;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final _search = TextEditingController(text: widget.filter.query);

  @override
  void didUpdateWidget(covariant FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A clear from outside the field (Clear filters, a family switch).
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
    final options = widget.options;
    final text = Theme.of(context).textTheme;
    final heading = AlbumText.group(text);

    Set<String> toggled(Set<String> ids, String id, bool on) =>
        on ? {...ids, id} : ({...ids}..remove(id));

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: AlbumSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: heading),
          const SizedBox(height: AlbumSpace.s),
          ...children,
        ],
      ),
    );

    Widget chips(List<Widget> children) => Wrap(
      spacing: AlbumSpace.s,
      runSpacing: AlbumSpace.s,
      children: children,
    );

    return Padding(
      padding: const EdgeInsets.all(AlbumSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Filters', style: text.titleLarge),
          if (filter.isActive) ...[
            const SizedBox(height: AlbumSpace.xs),
            Text(
              filterStatusLine(widget.matched, widget.total),
              key: const Key('filter-status'),
              style: AlbumText.count(text),
            ),
          ],
          const SizedBox(height: AlbumSpace.m),
          TextField(
            key: const Key('filter-search'),
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search titles, stories and people',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (query) =>
                widget.onChanged(filter.copyWith(query: query)),
          ),
          if (options.people.isNotEmpty)
            section('People', [
              chips([
                for (final person in options.people)
                  FilterChip(
                    key: Key('filter-person-${person.id}'),
                    label: _ChipLabel(person.name),
                    selected: filter.personIds.contains(person.id),
                    onSelected: (on) => widget.onChanged(
                      filter.copyWith(
                        personIds: toggled(filter.personIds, person.id, on),
                      ),
                    ),
                  ),
              ]),
            ]),
          if (options.places.isNotEmpty)
            section('Places', [
              chips([
                for (final place in options.places)
                  FilterChip(
                    key: Key('filter-place-${place.id}'),
                    label: _ChipLabel(place.label),
                    selected: filter.placeIds.contains(place.id),
                    onSelected: (on) => widget.onChanged(
                      filter.copyWith(
                        placeIds: toggled(filter.placeIds, place.id, on),
                      ),
                    ),
                  ),
              ]),
            ]),
          if (options.decades.length > 1)
            section('Years', [_decades(context, options.decades)]),
          if (filter.isActive) ...[
            const SizedBox(height: AlbumSpace.l),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('filter-clear'),
                onPressed: () => widget.onChanged(const TimelineFilter()),
                child: const Text('Clear filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A range over the loaded decades. A thumb at either end is an open
  /// bound, so a story added later in an outer decade still matches.
  Widget _decades(BuildContext context, List<int> decades) {
    final filter = widget.filter;
    int indexOf(int? decade, int fallback) {
      if (decade == null) return fallback;
      final at = decades.indexWhere((d) => d >= decade);
      return at < 0 ? decades.length - 1 : at;
    }

    final last = decades.length - 1;
    final from = indexOf(filter.fromDecade, 0);
    final to = filter.toDecade == null
        ? last
        : decades
              .lastIndexWhere((d) => d <= filter.toDecade!)
              .clamp(from, last);
    final values = RangeValues(from.toDouble(), to.toDouble());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${decades[from]}s – ${decades[to]}s',
          key: const Key('filter-decades-label'),
          style: AlbumText.axis(Theme.of(context).textTheme),
        ),
        RangeSlider(
          key: const Key('filter-decades'),
          min: 0,
          max: last.toDouble(),
          divisions: last,
          values: values,
          labels: RangeLabels('${decades[from]}s', '${decades[to]}s'),
          onChanged: (range) {
            final start = range.start.round();
            final end = range.end.round();
            widget.onChanged(
              filter.copyWith(
                fromDecade: () => start == 0 ? null : decades[start],
                toDecade: () => end == last ? null : decades[end],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A chip label that never fades: an explicit single-line ellipsis instead
/// of `RawChip`'s fade (the lab's web fix, handoff §2.1).
class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_theme.dart';
import '../../data/invite_api.dart';
import '../../data/people_api.dart';
import '../../data/perspectives_api.dart' show displayNameOrMember;
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/search_api.dart';
import '../../data/stories_api.dart';
import '../stories/timeframe_chips.dart';
import 'search_recents.dart';

const _noMatches = 'No stories match. Try another person, place, or time.';
const _searchingCopy = 'Searching the album…';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.inviteApi,
    this.peopleApi,
    this.placesApi,
    this.searchApi,
    this.photosApi,
    this.recents,
  });

  final InviteGateway? inviteApi;
  final PeopleGateway? peopleApi;
  final PlacesGateway? placesApi;
  final SearchGateway? searchApi;
  final PhotosGateway? photosApi;
  final SearchRecents? recents;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final InviteGateway _invite;
  late final PeopleGateway _peopleApi;
  late final PlacesGateway _placesApi;
  late final SearchGateway _searchApi;
  late final PhotosGateway _photos;
  late final SearchRecents _recents;
  late final TextEditingController _field;
  final _fieldFocus = FocusNode();

  Timer? _debounce;
  String? _familyId;
  List<Person> _people = const [];
  List<Place> _places = const [];
  List<SearchRecord> _results = const [];
  final _personIds = <String>[];
  String? _placeId;
  final _decades = <int>[];
  var _sort = SearchSort.relevant;
  var _searching = false;
  var _booting = true;

  @override
  void initState() {
    super.initState();
    _invite = widget.inviteApi ?? InviteApi();
    _peopleApi = widget.peopleApi ?? PeopleApi();
    _placesApi = widget.placesApi ?? PlacesApi();
    _searchApi = widget.searchApi ?? SearchApi();
    _photos = widget.photosApi ?? PhotosApi();
    _recents = widget.recents ?? SearchRecents();
    _field = TextEditingController();
    _recents.addListener(_onRecents);
    _boot();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recents.removeListener(_onRecents);
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _onRecents() {
    if (mounted) setState(() {});
  }

  bool get _active =>
      _field.text.trim().isNotEmpty ||
      _personIds.isNotEmpty ||
      _placeId != null ||
      _decades.isNotEmpty;

  Future<void> _boot() async {
    try {
      final familyId = await _invite.currentFamilyId();
      if (!mounted) return;
      List<Person> people = const [];
      List<Place> places = const [];
      if (familyId != null) {
        people = await _peopleApi.listPeople(familyId);
        places = await _placesApi.listPlaces(familyId);
      }
      if (!mounted) return;
      setState(() {
        _familyId = familyId;
        _people = people;
        _places = places;
        _booting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _booting = false);
      _showTryAgain();
    }
  }

  void _showTryAgain() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Try again'),
        action: SnackBarAction(label: 'Try again', onPressed: _retry),
      ),
    );
  }

  void _retry() {
    setState(() => _booting = true);
    _boot().whenComplete(() {
      if (_active) _runSearch();
    });
  }

  void _onTextChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  void _submit(String value) {
    _recents.remember(value);
    _debounce?.cancel();
    _runSearch();
  }

  Future<void> _runSearch() async {
    final familyId = _familyId;
    if (!_active || familyId == null) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searching = false;
        });
      }
      return;
    }
    setState(() => _searching = true);
    final bounds = decadeBounds(_decades);
    try {
      final rows = await _searchApi.search(
        SearchRequest(
          familyId: familyId,
          text: _field.text,
          personIds: List<String>.from(_personIds),
          placeId: _placeId,
          rangeStart: bounds?.$1,
          rangeEnd: bounds?.$2,
          sort: _sort,
        ),
      );
      if (!mounted) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
      _showTryAgain();
    }
  }

  void _clearText() {
    _field.clear();
    _onTextChanged('');
  }

  void _clearFilters() {
    setState(() {
      _personIds.clear();
      _placeId = null;
      _decades.clear();
    });
    _debounce?.cancel();
    _runSearch();
  }

  void _addPerson(String id) {
    if (_personIds.contains(id)) return;
    setState(() => _personIds.add(id));
    _debounce?.cancel();
    _runSearch();
  }

  void _setPlace(String id) {
    setState(() => _placeId = id);
    _debounce?.cancel();
    _runSearch();
  }

  void _addDecade(int startYear) {
    if (_decades.contains(startYear)) return;
    setState(() => _decades.add(startYear));
    _debounce?.cancel();
    _runSearch();
  }

  Future<void> _pickPerson() async {
    final available = _people.where((p) => !_personIds.contains(p.id)).toList();
    final picked = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Person'),
          content: SizedBox(
            width: 360,
            child: available.isEmpty
                ? const Text('No more people in this family.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final person in available)
                        ListTile(
                          title: Text(person.name),
                          onTap: () => Navigator.pop(context, person.id),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
    if (picked != null) _addPerson(picked);
  }

  Future<void> _pickDecade() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Decade'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final decade in decadeChips)
                if (!_decades.contains(decade.startYear))
                  TextButton(
                    onPressed: () => Navigator.pop(context, decade.startYear),
                    child: Text(decade.label),
                  ),
            ],
          ),
        );
      },
    );
    if (picked != null) _addDecade(picked);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.timeline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    children: [
                      if (_booting || _searching)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _searchingCopy,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      if (_active) _resultsHeader(),
                      if (_active && !_searching && _results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            _noMatches,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      if (_active && _results.isNotEmpty) _grid(),
                      const SizedBox(height: 28),
                      _recentSection(),
                      const SizedBox(height: 24),
                      _suggestedSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Material(
      color: albumParchment,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Tell Me a Story',
                  style: GoogleFonts.newsreader(
                    color: albumInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'SEARCH ARCHIVE',
                  style: GoogleFonts.sourceSans3(
                    color: albumInk.withValues(alpha: 0.55),
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _fieldBox()),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('search-close'),
                  onPressed: _close,
                  child: const Text('Close'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _filters(),
          ],
        ),
      ),
    );
  }

  Widget _fieldBox() {
    return TextField(
      key: const Key('search-field'),
      controller: _field,
      focusNode: _fieldFocus,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onTextChanged,
      onSubmitted: _submit,
      style: GoogleFonts.literata(color: albumInk),
      decoration: InputDecoration(
        hintText: 'Search stories by person, place, or time…',
        prefixIcon: const Icon(Icons.search, color: albumTerracotta),
        suffixIcon: _field.text.isEmpty
            ? null
            : IconButton(
                key: const Key('search-clear-text'),
                onPressed: _clearText,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _filters() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Filters:',
                style: GoogleFonts.sourceSans3(
                  color: albumInk.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              for (final id in _personIds)
                _FilterChip(
                  key: Key('search-filter-person-$id'),
                  label: _personName(id),
                  onRemove: () {
                    setState(() => _personIds.remove(id));
                    _runSearch();
                  },
                ),
              if (_placeId != null)
                _FilterChip(
                  key: const Key('search-filter-place'),
                  label: _placeLabel(_placeId!),
                  onRemove: () {
                    setState(() => _placeId = null);
                    _runSearch();
                  },
                ),
              if (_decades.isNotEmpty)
                _FilterChip(
                  key: const Key('search-filter-decade'),
                  label: decadeChipLabel(_decades),
                  onRemove: () {
                    setState(() => _decades.clear());
                    _runSearch();
                  },
                ),
              _AddPill(
                key: const Key('search-add-person'),
                label: 'Add Person',
                onTap: _pickPerson,
              ),
              _AddPill(
                key: const Key('search-add-decade'),
                label: 'Decade',
                onTap: _pickDecade,
              ),
            ],
          ),
        ),
        TextButton(
          key: const Key('search-clear'),
          onPressed: _clearFilters,
          child: const Text('Clear filters'),
        ),
      ],
    );
  }

  Widget _resultsHeader() {
    final count = _results.length;
    final noun = count == 1 ? 'result' : 'results';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Matching Archive Stories ($count $noun)',
              style: GoogleFonts.newsreader(
                color: albumInk,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text('Sort by:', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          DropdownButton<SearchSort>(
            key: const Key('search-sort'),
            value: _sort,
            items: const [
              DropdownMenuItem(
                value: SearchSort.relevant,
                child: Text('Most Relevant'),
              ),
              DropdownMenuItem(
                value: SearchSort.chronological,
                child: Text('Chronological'),
              ),
              DropdownMenuItem(
                value: SearchSort.recentlyAdded,
                child: Text('Recently Added'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _sort = value);
              _runSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final gap = 16.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final record in _results)
              SizedBox(
                width: width,
                child: _ResultCard(
                  record: record,
                  photos: _photos,
                  onOpen: () =>
                      context.push(AppRoutes.storyPath(record.story.id)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _recentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Searches',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in _recents.queries)
              ActionChip(
                label: Text(query),
                onPressed: () {
                  _field.text = query;
                  _field.selection = TextSelection.collapsed(
                    offset: query.length,
                  );
                  _submit(query);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _suggestedSection() {
    final people = _people.where((p) => !_personIds.contains(p.id));
    final places = _places.where((p) => p.id != _placeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Family Members & Places',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final person in people)
              ActionChip(
                key: Key('search-suggest-person-${person.id}'),
                avatar: const Icon(Icons.person, size: 18),
                label: Text(person.name),
                onPressed: () => _addPerson(person.id),
              ),
            for (final place in places)
              ActionChip(
                key: Key('search-suggest-place-${place.id}'),
                avatar: const Icon(Icons.place, size: 18),
                label: Text(place.label),
                onPressed: () => _setPlace(place.id),
              ),
          ],
        ),
      ],
    );
  }

  String _personName(String id) {
    for (final person in _people) {
      if (person.id == id) return person.name;
    }
    return 'Person';
  }

  String _placeLabel(String id) {
    for (final place in _places) {
      if (place.id == id) return place.label;
    }
    return 'Place';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumTerracotta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.sourceSans3(color: albumParchment)),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16, color: albumParchment),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.record,
    required this.photos,
    required this.onOpen,
  });

  final SearchRecord record;
  final PhotosGateway photos;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final story = record.story;
    final title = storedStoryTitle(story.title);
    final body = (story.body ?? '').trim();
    final year = '${story.timeframeStart.year}';
    final photoPath = story.photoPaths.isEmpty ? null : story.photoPaths.first;
    return Material(
      key: Key('search-result-${story.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoPath != null)
              _PhotoWell(
                path: photoPath,
                photos: photos,
                year: year,
                storyId: story.id,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _YearBadge(year: year, storyId: story.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in story.personNames)
                        _QuietOrFilledChip(
                          key: Key('search-card-person-$name'),
                          label: name,
                          filled: true,
                        ),
                      if ((story.placeLabel ?? '').isNotEmpty)
                        _QuietOrFilledChip(
                          key: Key('search-card-place-${story.placeLabel}'),
                          label: story.placeLabel!,
                          filled: false,
                        ),
                    ],
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.newsreader(
                        color: albumInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        color: albumInk.withValues(alpha: 0.75),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Added by ${displayNameOrMember(story.authorDisplayName)}',
                    style: GoogleFonts.sourceSans3(color: albumInk),
                  ),
                  TextButton(
                    onPressed: onOpen,
                    child: const Text('Read Story →'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoWell extends StatefulWidget {
  const _PhotoWell({
    required this.path,
    required this.photos,
    required this.year,
    required this.storyId,
  });

  final String path;
  final PhotosGateway photos;
  final String year;
  final String storyId;

  @override
  State<_PhotoWell> createState() => _PhotoWellState();
}

class _PhotoWellState extends State<_PhotoWell> {
  late final Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      return await widget.photos.downloadBytes(widget.path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _YearBadge(year: widget.year, storyId: widget.storyId),
          );
        }
        return SizedBox(
          key: Key('search-photo-${widget.storyId}'),
          height: 180,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _YearBadge(year: widget.year, storyId: widget.storyId),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YearBadge extends StatelessWidget {
  const _YearBadge({required this.year, required this.storyId});

  final String year;
  final String storyId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key('search-year-$storyId'),
      decoration: BoxDecoration(
        color: albumParchment.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(year, style: GoogleFonts.sourceSans3(color: albumInk)),
      ),
    );
  }
}

class _QuietOrFilledChip extends StatelessWidget {
  const _QuietOrFilledChip({
    super.key,
    required this.label,
    required this.filled,
  });

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? albumTerracotta : albumInk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.sourceSans3(
            color: filled ? albumParchment : albumInk,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

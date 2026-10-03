import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
import '../../data/mapbox_search.dart';
import '../../data/places_api.dart';
import 'place_map.dart';

/// Locked Mapbox failure copy (chrome lock).
const placeMapFailureCopy =
    'Couldn’t load the map. Check your connection and try again.';

/// Retry label for locked Mapbox failure UX.
const placeMapRetryLabel = 'Try again';

/// Optional map injection for tests (avoids real Mapbox tiles).
typedef PlaceMapBuilder = Widget Function({double? lat, double? lng});

enum _PlaceTab { favorites, recents, search }

const _searchHint = 'Search address or place…';

/// Place picker — favorites/recents + Mapbox search + basemap pin.
class PlacePickerModal extends StatefulWidget {
  const PlacePickerModal({
    super.key,
    required this.familyId,
    required this.places,
    required this.search,
    this.hasMapboxToken,
    this.mapBuilder,
  });

  final String familyId;
  final PlacesGateway places;
  final MapboxSearchGateway search;

  /// Defaults to [Env.hasMapboxToken]. Override in tests.
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  static Future<Place?> show(
    BuildContext context, {
    required String familyId,
    required PlacesGateway places,
    required MapboxSearchGateway search,
    bool? hasMapboxToken,
    PlaceMapBuilder? mapBuilder,
  }) {
    return showAlbumDialog<Place>(
      context: context,
      maxWidth: 672,
      builder: (ctx) => PlacePickerModal(
        familyId: familyId,
        places: places,
        search: search,
        hasMapboxToken: hasMapboxToken,
        mapBuilder: mapBuilder,
      ),
    );
  }

  @override
  State<PlacePickerModal> createState() => _PlacePickerModalState();
}

class _PlacePickerModalState extends State<PlacePickerModal> {
  final _searchController = TextEditingController();

  List<Place>? _favorites;
  List<Place>? _recents;
  List<MapboxSearchHit> _hits = const [];
  Place? _pending;
  var _tab = _PlaceTab.favorites;

  var _mapFailed = false;
  var _busy = false;
  var _searching = false;
  Timer? _debounce;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  @override
  void initState() {
    super.initState();
    if (!_tokenOk) {
      _mapFailed = true;
    }
    _loadLists();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final favorites = await widget.places.listFavorites(widget.familyId);
      final recents = await widget.places.listRecents(widget.familyId);
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _recents = recents;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favorites = const [];
        _recents = const [];
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String query) async {
    if (!_tokenOk) {
      setState(() => _mapFailed = true);
      return;
    }
    setState(() {
      _searching = true;
      _mapFailed = false;
    });
    try {
      final hits = await widget.search.search(query);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
        if (hits.isNotEmpty) _tab = _PlaceTab.search;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hits = const [];
        _searching = false;
        _mapFailed = true;
      });
    }
  }

  Future<void> _retryMap() async {
    setState(() {
      _mapFailed = !_tokenOk;
      _hits = const [];
    });
    await _loadLists();
    final q = _searchController.text.trim();
    if (q.isNotEmpty && _tokenOk) {
      await _runSearch(q);
    }
  }

  Future<void> _selectExisting(Place place) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.places.markUsed(place.id);
      if (!mounted) return;
      setState(() {
        _pending = updated;
        _busy = false;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update place. Try again.')),
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _selectHit(MapboxSearchHit hit) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final existing = await widget.places.findByMapboxPlaceId(
        widget.familyId,
        hit.id,
      );
      final Place place;
      if (existing != null) {
        place = await widget.places.markUsed(existing.id);
      } else {
        place = await widget.places.createPlace(
          familyId: widget.familyId,
          label: hit.label,
          address: hit.address,
          lat: hit.lat,
          lng: hit.lng,
          mapboxPlaceId: hit.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _pending = place;
        _busy = false;
        _hits = const [];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save place. Try again.')),
      );
      setState(() => _busy = false);
    }
  }

  void _confirmPending() {
    final place = _pending;
    if (place == null) return;
    Navigator.of(context).pop(place);
  }

  Future<void> _togglePendingFavorite() async {
    final place = _pending;
    if (place == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.places.setFavorite(
        placeId: place.id,
        isFavorite: !place.isFavorite,
      );
      if (!mounted) return;
      setState(() {
        _pending = updated;
        _busy = false;
      });
      await _loadLists();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update favorite. Try again.')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose place',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tag a memorable location, family heirloom home, or address to pin on your story map',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF6B5E55),
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF6B5E55)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _searchHint,
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                prefixIconColor: const Color(0xFFA8A29E),
                hintStyle: const TextStyle(
                  color: Color(0xFFA8A29E),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: _fieldBorder(),
                enabledBorder: _fieldBorder(),
                focusedBorder: _fieldBorder(color: albumTerracotta, width: 1.5),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                _runSearch(value.trim());
              },
            ),
            const SizedBox(height: 12),
            _tabBar(),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              ),
            _tabBody(),
            const SizedBox(height: 12),
            _buildMapArea(),
            if (_pending != null) ...[
              const SizedBox(height: 12),
              _selectedPlaceCard(),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEAE1D3)),
            const SizedBox(height: 12),
            _footer(),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder({
    Color color = const Color(0xFFDCD3C4),
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _footer() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return Row(
      children: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: const Color(0xFF4A3E38),
            side: const BorderSide(color: Color(0xFFDCD3C4)),
            shape: shape,
          ),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _busy || _pending == null ? null : _confirmPending,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: albumTerracotta,
            foregroundColor: Colors.white,
            disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.35),
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Use this place'),
        ),
      ],
    );
  }

  Widget _tabBar() {
    final count = _favorites?.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _tabButton(
              tab: _PlaceTab.favorites,
              icon: Icons.star,
              label: 'Favorites',
              badge: count == null ? null : '$count',
            ),
            _tabButton(
              tab: _PlaceTab.recents,
              icon: Icons.history,
              label: 'Recents',
            ),
            _tabButton(
              tab: _PlaceTab.search,
              icon: Icons.travel_explore,
              label: 'All Places / Search',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required _PlaceTab tab,
    required IconData icon,
    required String label,
    String? badge,
  }) {
    final selected = _tab == tab;
    final foreground = selected ? Colors.white : const Color(0xFF6B5E55);
    return Expanded(
      child: Material(
        color: selected ? albumTerracotta : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _busy
              ? null
              : () => setState(() {
                  _tab = tab;
                }),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    '($badge)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case _PlaceTab.favorites:
        return _placeSection(places: _favorites, empty: 'No favorites yet.');
      case _PlaceTab.recents:
        return _placeSection(places: _recents, empty: 'No recent places yet.');
      case _PlaceTab.search:
        if (_hits.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Type an address to search.'),
          );
        }
        return _hitCards();
    }
  }

  Widget _placeSection({required List<Place>? places, required String empty}) {
    if (places == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (places.isEmpty) return Text(empty);
    return _placeCards(places);
  }

  Widget _placeCards(List<Place> places) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 520 ? 3 : 1;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final place in places)
              SizedBox(
                width: width,
                child: _placeCard(
                  label: place.label,
                  address: place.address,
                  selected: _pending?.id == place.id,
                  onTap: _busy ? null : () => _selectExisting(place),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _hitCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 520 ? 3 : 1;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final hit in _hits)
              SizedBox(
                width: width,
                child: _placeCard(
                  label: hit.label,
                  address: hit.address,
                  selected: false,
                  onTap: _busy ? null : () => _selectHit(hit),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _placeCard({
    required String label,
    required String address,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFAF5EE) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? albumTerracotta : const Color(0xFFE7DECE),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: selected
                        ? albumTerracotta
                        : const Color(0xFFF3EDE6),
                    child: Icon(
                      Icons.location_on,
                      size: 16,
                      color: selected ? Colors.white : const Color(0xFF554942),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      color: albumTerracotta,
                      size: 18,
                    )
                  else
                    Text(
                      'Select',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF817976),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF6B5E55),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedPlaceCard() {
    final place = _pending!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DFC8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: albumTerracotta.withValues(alpha: 0.15),
            child: const Icon(
              Icons.location_on,
              size: 16,
              color: albumTerracotta,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        place.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(
                      ' — ',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 14),
                    ),
                    Flexible(
                      child: Text(
                        place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (place.isFavorite)
                  Text(
                    'Already in Family Favorites',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF6B5E55),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('place-favorite-toggle'),
            onPressed: _busy ? null : _togglePendingFavorite,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF554942),
              side: const BorderSide(color: Color(0xFFDCD3C4)),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.white,
            ),
            icon: Icon(
              place.isFavorite ? Icons.bookmark : Icons.bookmark_border,
              size: 16,
              color: albumTerracotta,
            ),
            label: const Text('Favorite'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    if (_mapFailed || !_tokenOk) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(placeMapFailureCopy),
          TextButton(
            onPressed: _busy ? null : _retryMap,
            child: const Text(placeMapRetryLabel),
          ),
        ],
      );
    }

    final lat = _pending?.lat;
    final lng = _pending?.lng;
    final builder = widget.mapBuilder;
    final map = builder != null
        ? builder(lat: lat, lng: lng)
        : PlaceMap(
            lat: lat,
            lng: lng,
            height: 176,
            onTileError: (error, stackTrace) {
              if (!mounted) return;
              setState(() => _mapFailed = true);
            },
          );
    final pending = _pending;
    return Stack(
      children: [
        map,
        if (pending != null)
          Positioned(
            top: 8,
            left: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE7DECE)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  'Pin preview · ${pending.label}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

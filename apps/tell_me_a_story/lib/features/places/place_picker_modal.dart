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
      maxWidth: 720,
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
      Navigator.of(context).pop(updated);
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
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: viewInsets.bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose place',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                enabled: !_busy,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search places',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _runSearch(value.trim());
                },
              ),
              const SizedBox(height: 12),
              _buildMapArea(),
              if (_pending != null) ...[
                const SizedBox(height: 8),
                _selectedPlaceCard(),
              ],
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_hits.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _hits.length,
                    itemBuilder: (context, index) {
                      final hit = _hits[index];
                      return ListTile(
                        dense: true,
                        title: Text(hit.label),
                        subtitle: Text(hit.address),
                        onTap: _busy ? null : () => _selectHit(hit),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(child: _buildLists()),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(albumCardRadius),
        border: Border.all(color: albumSage.withValues(alpha: 0.45)),
      ),
      child: Column(
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
                      place.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      place.address,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('place-favorite-toggle'),
                tooltip: place.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: _busy ? null : _togglePendingFavorite,
                icon: Icon(
                  place.isFavorite ? Icons.star : Icons.star_border,
                  color: albumTerracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _confirmPending,
            child: const Text('Use this place'),
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
    if (builder != null) {
      return builder(lat: lat, lng: lng);
    }
    return PlaceMap(
      lat: lat,
      lng: lng,
      onTileError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _mapFailed = true);
      },
    );
  }

  Widget _buildLists() {
    final favorites = _favorites;
    final recents = _recents;
    if (favorites == null || recents == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Text('Favorites', style: Theme.of(context).textTheme.titleSmall),
        if (favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No favorites yet.'),
          )
        else
          ...favorites.map(
            (p) => ListTile(
              title: Text(p.label),
              subtitle: Text(p.address),
              leading: const Icon(Icons.star),
              onTap: _busy ? null : () => _selectExisting(p),
            ),
          ),
        const SizedBox(height: 8),
        Text('Recents', style: Theme.of(context).textTheme.titleSmall),
        if (recents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No recent places yet.'),
          )
        else
          ...recents.map(
            (p) => ListTile(
              title: Text(p.label),
              subtitle: Text(p.address),
              leading: const Icon(Icons.history),
              onTap: _busy ? null : () => _selectExisting(p),
            ),
          ),
      ],
    );
  }
}

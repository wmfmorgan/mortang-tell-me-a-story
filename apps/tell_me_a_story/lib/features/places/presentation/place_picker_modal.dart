import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tell_me_a_story/core/domain/mapbox_search_hit.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/env.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/features/places/presentation/place_map.dart';
import 'package:tell_me_a_story/features/places/presentation/place_picker_providers.dart';

/// Locked Mapbox failure copy (chrome lock).
const placeMapFailureCopy =
    'Couldn’t load the map. Check your connection and try again.';

/// Retry label for locked Mapbox failure UX.
const placeMapRetryLabel = 'Try again';

/// Optional map injection for tests (avoids real Mapbox tiles).
typedef PlaceMapBuilder = Widget Function({double? lat, double? lng});

enum _PlaceTab { favorites, recents, search }

const _searchHint = 'Search address or place…';

const _mutedInk = Color(0xFF6B5E55);

/// Place picker — favorites/recents + Mapbox search + basemap pin.
class PlacePickerModal extends ConsumerStatefulWidget {
  const PlacePickerModal({
    super.key,
    required this.familyId,
    this.hasMapboxToken,
    this.mapBuilder,
  });

  final String familyId;

  /// Defaults to [Env.hasMapboxToken]. Override in tests.
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  static Future<Place?> show(
    BuildContext context, {
    required String familyId,
    bool? hasMapboxToken,
    PlaceMapBuilder? mapBuilder,
  }) {
    return showAlbumDialog<Place>(
      context: context,
      maxWidth: 672,
      builder: (ctx) => PlacePickerModal(
        familyId: familyId,
        hasMapboxToken: hasMapboxToken,
        mapBuilder: mapBuilder,
      ),
    );
  }

  @override
  ConsumerState<PlacePickerModal> createState() => _PlacePickerModalState();
}

class _PlacePickerModalState extends ConsumerState<PlacePickerModal> {
  final _searchController = TextEditingController();

  List<MapboxSearchHit> _hits = const [];
  Place? _pending;
  var _tab = _PlaceTab.favorites;

  var _mapFailed = false;
  var _busy = false;
  var _searching = false;
  Timer? _debounce;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  PlacesRepository get _places => ref.read(placesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (!_tokenOk) {
      _mapFailed = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reloadLists() {
    ref.invalidate(placePickerListsProvider(widget.familyId));
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

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    _runSearch(value.trim());
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
      final hits = await ref.read(mapboxSearchRepositoryProvider).search(query);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
        if (hits.isNotEmpty) _tab = _PlaceTab.search;
      });
    } catch (_) {
      // Boundary: any search failure shows the locked map failure copy.
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
    _reloadLists();
    final q = _searchController.text.trim();
    if (q.isNotEmpty && _tokenOk) {
      await _runSearch(q);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectExisting(Place place) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _places.markUsed(place.id);
      if (!mounted) return;
      setState(() {
        _pending = updated;
        _busy = false;
      });
    } catch (_) {
      // Boundary: mapped to the locked snack copy.
      if (!mounted) return;
      _showSnack('Couldn’t update place. Try again.');
      setState(() => _busy = false);
    }
  }

  Future<Place> _placeForHit(MapboxSearchHit hit) async {
    final places = _places;
    final existing = await places.findByMapboxPlaceId(widget.familyId, hit.id);
    if (existing != null) return places.markUsed(existing.id);
    return places.createPlace(
      familyId: widget.familyId,
      label: hit.label,
      address: hit.address,
      lat: hit.lat,
      lng: hit.lng,
      mapboxPlaceId: hit.id,
    );
  }

  Future<void> _selectHit(MapboxSearchHit hit) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final place = await _placeForHit(hit);
      if (!mounted) return;
      setState(() {
        _pending = place;
        _busy = false;
        _hits = const [];
      });
    } catch (_) {
      // Boundary: mapped to the locked snack copy.
      if (!mounted) return;
      _showSnack('Couldn’t save place. Try again.');
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
      final updated = await _places.setFavorite(
        placeId: place.id,
        isFavorite: !place.isFavorite,
      );
      if (!mounted) return;
      setState(() {
        _pending = updated;
        _busy = false;
      });
      _reloadLists();
    } catch (_) {
      // Boundary: mapped to the locked snack copy.
      if (!mounted) return;
      _showSnack('Couldn’t update favorite. Try again.');
      setState(() => _busy = false);
    }
  }

  void _onMapTileError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() => _mapFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return _ModalScroll(
      children: [
        _Header(busy: _busy),
        _SearchField(
          controller: _searchController,
          enabled: !_busy,
          onChanged: _onSearchChanged,
          onSubmitted: _onSearchSubmitted,
        ),
        _PickerTabs(
          familyId: widget.familyId,
          tab: _tab,
          searching: _searching,
          hits: _hits,
          pendingId: pending?.id,
          onTab: _busy ? null : (tab) => setState(() => _tab = tab),
          onSelectPlace: _busy ? null : _selectExisting,
          onSelectHit: _busy ? null : _selectHit,
        ),
        _MapArea(
          failed: _mapFailed || !_tokenOk,
          onRetry: _busy ? null : _retryMap,
          mapBuilder: widget.mapBuilder,
          pending: pending,
          onTileError: _onMapTileError,
        ),
        if (pending != null)
          _SelectedPlaceCard(
            place: pending,
            onToggleFavorite: _busy ? null : _togglePendingFavorite,
          ),
        const Divider(height: 1, color: Color(0xFFEAE1D3)),
        _Footer(
          busy: _busy,
          onConfirm: _busy || pending == null ? null : _confirmPending,
        ),
      ],
    );
  }
}

class _ModalScroll extends StatelessWidget {
  const _ModalScroll({required this.children});

  final List<Widget> children;

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
          spacing: 12,
          children: children,
        ),
      ),
    );
  }
}

class _PickerTabs extends ConsumerWidget {
  const _PickerTabs({
    required this.familyId,
    required this.tab,
    required this.searching,
    required this.hits,
    required this.pendingId,
    required this.onTab,
    required this.onSelectPlace,
    required this.onSelectHit,
  });

  final String familyId;
  final _PlaceTab tab;
  final bool searching;
  final List<MapboxSearchHit> hits;
  final String? pendingId;
  final ValueChanged<_PlaceTab>? onTab;
  final ValueChanged<Place>? onSelectPlace;
  final ValueChanged<MapboxSearchHit>? onSelectHit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(placePickerListsProvider(familyId));
    // Load failures render as empty lists (today's behaviour).
    final loaded = lists.hasError ? PlacePickerLists.empty : lists.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabBar(
          selected: tab,
          favoritesCount: loaded?.favorites.length,
          onSelect: onTab,
        ),
        const SizedBox(height: 12),
        if (searching)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        _TabBody(
          tab: tab,
          lists: loaded,
          hits: hits,
          pendingId: pendingId,
          onSelectPlace: onSelectPlace,
          onSelectHit: onSelectHit,
        ),
      ],
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({
    required this.failed,
    required this.onRetry,
    required this.mapBuilder,
    required this.pending,
    required this.onTileError,
  });

  final bool failed;
  final VoidCallback? onRetry;
  final PlaceMapBuilder? mapBuilder;
  final Place? pending;
  final void Function(Object error, StackTrace? stackTrace) onTileError;

  @override
  Widget build(BuildContext context) {
    if (failed) return _MapFailure(onRetry: onRetry);
    final pending = this.pending;
    final lat = pending?.lat;
    final lng = pending?.lng;
    final builder = mapBuilder;
    final map = builder != null
        ? builder(lat: lat, lng: lng)
        : PlaceMap(lat: lat, lng: lng, height: 176, onTileError: onTileError);
    return Stack(
      children: [
        map,
        if (pending != null)
          Positioned(top: 8, left: 8, child: _PinPreview(label: pending.label)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose place',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tag a memorable location, family heirloom home, or address to pin on your story map',
                style: textTheme.labelSmall?.copyWith(
                  color: _mutedInk,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: _mutedInk),
        ),
      ],
    );
  }
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: _searchHint,
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        prefixIconColor: const Color(0xFFA8A29E),
        hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: _fieldBorder(),
        enabledBorder: _fieldBorder(),
        focusedBorder: _fieldBorder(color: albumTerracotta, width: 1.5),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.busy, required this.onConfirm});

  final bool busy;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return Row(
      children: [
        OutlinedButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
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
          onPressed: onConfirm,
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
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.favoritesCount,
    required this.onSelect,
  });

  final _PlaceTab selected;
  final int? favoritesCount;
  final ValueChanged<_PlaceTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    final count = favoritesCount;
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
            _TabButton(
              tab: _PlaceTab.favorites,
              current: selected,
              icon: Icons.star,
              label: 'Favorites',
              badge: count == null ? null : '$count',
              onSelect: onSelect,
            ),
            _TabButton(
              tab: _PlaceTab.recents,
              current: selected,
              icon: Icons.history,
              label: 'Recents',
              onSelect: onSelect,
            ),
            _TabButton(
              tab: _PlaceTab.search,
              current: selected,
              icon: Icons.travel_explore,
              label: 'All Places / Search',
              onSelect: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.current,
    required this.icon,
    required this.label,
    required this.onSelect,
    this.badge,
  });

  final _PlaceTab tab;
  final _PlaceTab current;
  final IconData icon;
  final String label;
  final String? badge;
  final ValueChanged<_PlaceTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = tab == current;
    return Expanded(
      child: Material(
        color: selected ? albumTerracotta : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _bind(onSelect, tab),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: _TabButtonLabel(
              selected: selected,
              icon: icon,
              label: label,
              badge: badge,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButtonLabel extends StatelessWidget {
  const _TabButtonLabel({
    required this.selected,
    required this.icon,
    required this.label,
    required this.badge,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _mutedInk;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: foreground, fontSize: 13);
    final badge = this.badge;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 2),
          Text('($badge)', style: style?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tab,
    required this.lists,
    required this.hits,
    required this.pendingId,
    required this.onSelectPlace,
    required this.onSelectHit,
  });

  final _PlaceTab tab;

  /// Null while the first load is in flight.
  final PlacePickerLists? lists;
  final List<MapboxSearchHit> hits;
  final String? pendingId;
  final ValueChanged<Place>? onSelectPlace;
  final ValueChanged<MapboxSearchHit>? onSelectHit;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      _PlaceTab.favorites => _PlaceSection(
        places: lists?.favorites,
        empty: 'No favorites yet.',
        pendingId: pendingId,
        onSelect: onSelectPlace,
      ),
      _PlaceTab.recents => _PlaceSection(
        places: lists?.recents,
        empty: 'No recent places yet.',
        pendingId: pendingId,
        onSelect: onSelectPlace,
      ),
      _PlaceTab.search when hits.isEmpty => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Type an address to search.'),
      ),
      _PlaceTab.search => _CardGrid(
        children: [
          for (final hit in hits)
            _PlaceCard(
              label: hit.label,
              address: hit.address,
              selected: false,
              onTap: _bind(onSelectHit, hit),
            ),
        ],
      ),
    };
  }
}

class _PlaceSection extends StatelessWidget {
  const _PlaceSection({
    required this.places,
    required this.empty,
    required this.pendingId,
    required this.onSelect,
  });

  /// Null while the first load is in flight.
  final List<Place>? places;
  final String empty;
  final String? pendingId;
  final ValueChanged<Place>? onSelect;

  @override
  Widget build(BuildContext context) {
    final places = this.places;
    if (places == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (places.isEmpty) return Text(empty);
    return _CardGrid(
      children: [
        for (final place in places)
          _PlaceCard(
            label: place.label,
            address: place.address,
            selected: pendingId == place.id,
            onTap: _bind(onSelect, place),
          ),
      ],
    );
  }
}

VoidCallback? _bind<T>(ValueChanged<T>? callback, T value) {
  if (callback == null) return null;
  return () => callback(value);
}

/// One column on narrow layouts, three at 520px and wider.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 520 ? 3 : 1;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.label,
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String address;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              _PlaceCardTitle(label: label, selected: selected),
              const SizedBox(height: 4),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: _mutedInk, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceCardTitle extends StatelessWidget {
  const _PlaceCardTitle({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: selected ? albumTerracotta : const Color(0xFFF3EDE6),
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
            style: textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (selected)
          const Icon(Icons.check_circle, color: albumTerracotta, size: 18)
        else
          Text(
            'Select',
            style: textTheme.labelSmall?.copyWith(
              color: albumSage,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({
    required this.place,
    required this.onToggleFavorite,
  });

  final Place place;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: _SelectedPlaceText(place: place)),
          const SizedBox(width: 8),
          _FavoriteToggle(
            isFavorite: place.isFavorite,
            onPressed: onToggleFavorite,
          ),
        ],
      ),
    );
  }
}

class _FavoriteToggle extends StatelessWidget {
  const _FavoriteToggle({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('place-favorite-toggle'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF554942),
        side: const BorderSide(color: Color(0xFFDCD3C4)),
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.white,
      ),
      icon: Icon(
        isFavorite ? Icons.bookmark : Icons.bookmark_border,
        size: 16,
        color: albumTerracotta,
      ),
      label: const Text('Favorite'),
    );
  }
}

class _SelectedPlaceText extends StatelessWidget {
  const _SelectedPlaceText({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleMedium?.copyWith(fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                place.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            Text(' — ', style: titleStyle),
            Flexible(
              child: Text(
                place.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ],
        ),
        if (place.isFavorite)
          Text(
            'Already in Family Favorites',
            style: textTheme.labelSmall?.copyWith(
              color: _mutedInk,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _MapFailure extends StatelessWidget {
  const _MapFailure({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(placeMapFailureCopy),
        TextButton(onPressed: onRetry, child: const Text(placeMapRetryLabel)),
      ],
    );
  }
}

class _PinPreview extends StatelessWidget {
  const _PinPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'Pin preview · $label',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/places_api.dart';
import '../people/add_person_modal.dart';
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';

/// Minimal M3 `/stories/new` shell — people chips + place only.
/// Capture body / draft / publish arrive in M4. Selection is in-memory only.
class NewStoryPage extends StatefulWidget {
  const NewStoryPage({
    super.key,
    this.inviteApi,
    this.peopleApi,
    this.placesApi,
    this.mapboxSearch,
    this.hasMapboxToken,
    this.mapBuilder,
  });

  final InviteGateway? inviteApi;
  final PeopleGateway? peopleApi;
  final PlacesGateway? placesApi;
  final MapboxSearchGateway? mapboxSearch;

  /// Defaults to [Env.hasMapboxToken] inside [PlacePickerModal].
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  @override
  State<NewStoryPage> createState() => _NewStoryPageState();
}

class _NewStoryPageState extends State<NewStoryPage> {
  late final InviteGateway _invite;
  late final PeopleGateway _people;
  late final PlacesGateway _places;
  late final MapboxSearchGateway _search;

  String? _familyId;
  var _loadingFamily = true;
  var _busy = false;

  final List<Person> _selectedPeople = [];
  Place? _selectedPlace;
  var _shellMapFailed = false;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  @override
  void initState() {
    super.initState();
    _invite = widget.inviteApi ?? InviteApi();
    _people = widget.peopleApi ?? PeopleApi();
    _places = widget.placesApi ?? PlacesApi();
    _search = widget.mapboxSearch ?? MapboxSearchApi();
    _shellMapFailed = !_tokenOk;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _invite.currentFamilyId();
      if (!mounted) return;
      setState(() {
        _familyId = id;
        _loadingFamily = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFamily = false);
    }
  }

  Future<String?> _ensureFamilyId() async {
    var familyId = _familyId;
    if (familyId != null) return familyId;
    familyId = await _invite.createFamily('Family');
    if (!mounted) return null;
    setState(() => _familyId = familyId);
    return familyId;
  }

  Future<void> _openAddPerson() async {
    if (_busy || _loadingFamily) return;
    setState(() => _busy = true);
    try {
      final familyId = await _ensureFamilyId();
      if (!mounted || familyId == null) return;
      final person = await AddPersonModal.show(
        context,
        familyId: familyId,
        api: _people,
      );
      if (!mounted || person == null) return;
      if (_selectedPeople.any((p) => p.id == person.id)) return;
      setState(() => _selectedPeople.add(person));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openChoosePlace() async {
    if (_busy || _loadingFamily) return;
    setState(() => _busy = true);
    try {
      final familyId = await _ensureFamilyId();
      if (!mounted || familyId == null) return;
      final place = await PlacePickerModal.show(
        context,
        familyId: familyId,
        places: _places,
        search: _search,
        hasMapboxToken: widget.hasMapboxToken,
        mapBuilder: widget.mapBuilder,
      );
      if (!mounted || place == null) return;
      setState(() {
        _selectedPlace = place;
        _shellMapFailed = !_tokenOk;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removePerson(Person person) {
    setState(() => _selectedPeople.removeWhere((p) => p.id == person.id));
  }

  void _retryShellMap() {
    setState(() => _shellMapFailed = !_tokenOk);
  }

  @override
  Widget build(BuildContext context) {
    final place = _selectedPlace;
    final actionsEnabled = !_loadingFamily && !_busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New story'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('People', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final person in _selectedPeople)
                  Chip(
                    label: Text(person.name),
                    onDeleted: () => _removePerson(person),
                  ),
                TextButton(
                  onPressed: actionsEnabled ? _openAddPerson : null,
                  child: const Text('Add person'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Place', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (place != null) ...[
              _buildSelectedPlaceMap(place),
              const SizedBox(height: 8),
              Text(place.label, style: Theme.of(context).textTheme.titleSmall),
              Text(
                place.address,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: actionsEnabled ? _openChoosePlace : null,
                child: const Text('Choose place'),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Capture fields arrive in M4.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPlaceMap(Place place) {
    if (_shellMapFailed || !_tokenOk) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(placeMapFailureCopy),
          TextButton(
            onPressed: _retryShellMap,
            child: const Text(placeMapRetryLabel),
          ),
        ],
      );
    }

    final builder = widget.mapBuilder;
    if (builder != null) {
      return builder(lat: place.lat, lng: place.lng);
    }
    return PlaceMap(
      lat: place.lat,
      lng: place.lng,
      height: 140,
      onTileError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _shellMapFailed = true);
      },
    );
  }
}

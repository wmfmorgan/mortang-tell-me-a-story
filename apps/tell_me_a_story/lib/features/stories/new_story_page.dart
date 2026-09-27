import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/places_api.dart';
import '../../data/stories_api.dart';
import '../people/add_person_modal.dart';
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';
import 'timeframe_chips.dart';

const _terracotta = Color(0xFF8B5E4B);

/// Capture form for `/stories/new` — timeframe, people, place, body, persist.
class NewStoryPage extends StatefulWidget {
  const NewStoryPage({
    super.key,
    this.inviteApi,
    this.peopleApi,
    this.placesApi,
    this.mapboxSearch,
    this.storiesApi,
    this.hasMapboxToken,
    this.mapBuilder,
    this.draftId,
  });

  final InviteGateway? inviteApi;
  final PeopleGateway? peopleApi;
  final PlacesGateway? placesApi;
  final MapboxSearchGateway? mapboxSearch;
  final StoriesGateway? storiesApi;

  /// Defaults to [Env.hasMapboxToken] inside [PlacePickerModal].
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  /// Resume a draft via `/stories/new?draft=`.
  final String? draftId;

  @override
  State<NewStoryPage> createState() => _NewStoryPageState();
}

class _NewStoryPageState extends State<NewStoryPage> {
  late final InviteGateway _invite;
  late final PeopleGateway _people;
  late final PlacesGateway _places;
  late final MapboxSearchGateway _search;
  StoriesGateway? _storiesOverride;

  final _body = TextEditingController();

  String? _familyId;
  String? _storyId;
  var _loadingFamily = true;
  var _busy = false;
  var _showPublishBanner = false;

  DateTime? _timeframeStart;
  DateTime? _timeframeEnd;
  final List<Person> _selectedPeople = [];
  Place? _selectedPlace;
  String? _placeId;
  var _shellMapFailed = false;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PublishReadiness get _readiness => publishReadiness(
    body: _body.text,
    timeframeStart: _timeframeStart,
    personIds: _selectedPeople.map((p) => p.id),
    placeId: _selectedPlace?.id ?? _placeId,
  );

  bool get _actionsEnabled => !_loadingFamily && !_busy;

  bool get _canSaveDraft => _actionsEnabled && _timeframeStart != null;

  @override
  void initState() {
    super.initState();
    _invite = widget.inviteApi ?? InviteApi();
    _people = widget.peopleApi ?? PeopleApi();
    _places = widget.placesApi ?? PlacesApi();
    _search = widget.mapboxSearch ?? MapboxSearchApi();
    _shellMapFailed = !_tokenOk;
    _storyId = widget.draftId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _invite.currentFamilyId();
      if (!mounted) return;
      setState(() {
        _familyId = id;
        _loadingFamily = false;
      });
      final draftId = widget.draftId;
      if (draftId != null) {
        await _hydrateDraft(draftId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFamily = false);
    }
  }

  Future<void> _hydrateDraft(String draftId) async {
    final story = await _stories.getStory(draftId);
    if (!mounted) return;
    final familyId = story.familyId;
    final people = await _people.listPeople(familyId);
    Place? place;
    final placeId = story.placeId;
    if (placeId != null && placeId.isNotEmpty) {
      final favorites = await _places.listFavorites(familyId);
      final recents = await _places.listRecents(familyId);
      for (final candidate in [...favorites, ...recents]) {
        if (candidate.id == placeId) {
          place = candidate;
          break;
        }
      }
    }
    if (!mounted) return;
    final decade = DecadeRange.containing(story.timeframeStart);
    setState(() {
      _storyId = story.id;
      _familyId = familyId;
      _timeframeStart = decade?.start ?? story.timeframeStart;
      _timeframeEnd = decade?.end ?? story.timeframeEnd;
      _body.text = story.body ?? '';
      _selectedPeople
        ..clear()
        ..addAll(people.where((p) => story.personIds.contains(p.id)));
      _selectedPlace = place;
      _placeId = placeId;
      _shellMapFailed = !_tokenOk;
    });
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
        _placeId = place.id;
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

  void _selectDecade(DecadeRange decade) {
    setState(() {
      _timeframeStart = decade.start;
      _timeframeEnd = decade.end;
    });
  }

  Future<Story?> _persistDraft() async {
    final familyId = await _ensureFamilyId();
    final start = _timeframeStart;
    if (!mounted || familyId == null || start == null) return null;
    final personIds = _selectedPeople.map((p) => p.id).toList();
    final placeId = _selectedPlace?.id ?? _placeId;
    final body = _body.text;
    final existingId = _storyId;
    final story = existingId == null
        ? await _stories.createDraft(
            familyId: familyId,
            timeframeStart: start,
            timeframeEnd: _timeframeEnd,
            body: body,
            placeId: placeId,
            personIds: personIds,
          )
        : await _stories.updateDraft(
            storyId: existingId,
            timeframeStart: start,
            timeframeEnd: _timeframeEnd,
            body: body,
            placeId: placeId,
            personIds: personIds,
          );
    if (!mounted) return story;
    setState(() => _storyId = story.id);
    return story;
  }

  Future<void> _onSaveDraft() async {
    if (!_canSaveDraft) return;
    setState(() => _busy = true);
    try {
      await _persistDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onPublish() async {
    if (!_actionsEnabled) return;
    final readiness = _readiness;
    if (!readiness.canPublish) {
      setState(() => _showPublishBanner = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted || story == null) return;
      await _stories.publish(story.id);
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(AppRoutes.timeline);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _selectedPlace;
    final readiness = _readiness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New story'),
        actions: [
          TextButton(
            onPressed: _canSaveDraft ? _onSaveDraft : null,
            child: const Text('Save draft'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _actionsEnabled ? _onPublish : null,
              child: const Text('Publish story'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showPublishBanner) ...[
                const Text('Finish the highlighted fields to publish.'),
                const SizedBox(height: 16),
              ],
              if (readiness.canPublish) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text('Ready to publish')),
                ),
                const SizedBox(height: 16),
              ],
              _highlightIfMissing(
                missing: !readiness.hasTimeframe,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeframe',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TimeframeChips(
                      selectedStartYear: _timeframeStart == null
                          ? null
                          : DecadeRange.containing(_timeframeStart!)?.startYear,
                      onSelected: _selectDecade,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _highlightIfMissing(
                missing: !readiness.hasPerson,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'People',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                          onPressed: _actionsEnabled ? _openAddPerson : null,
                          child: const Text('Add person'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _highlightIfMissing(
                missing: !readiness.hasPlace,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Place',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (place != null) ...[
                      _buildSelectedPlaceMap(place),
                      const SizedBox(height: 8),
                      Text(
                        place.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        place.address,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _actionsEnabled ? _openChoosePlace : null,
                        child: const Text('Choose place'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _highlightIfMissing(
                missing: !readiness.hasBody,
                child: TextField(
                  controller: _body,
                  minLines: 5,
                  maxLines: null,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Story',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlightIfMissing({required bool missing, required Widget child}) {
    if (!_showPublishBanner || !missing) return child;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _terracotta, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: child,
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

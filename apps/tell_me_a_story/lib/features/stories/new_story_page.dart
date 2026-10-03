import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/stories_api.dart';
import '../people/add_person_modal.dart';
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';
import 'photo_strip.dart';
import 'timeframe_chips.dart';

/// Capture form for `/stories/new` — timeframe, people, place, body, persist.
class NewStoryPage extends StatefulWidget {
  const NewStoryPage({
    super.key,
    this.inviteApi,
    this.peopleApi,
    this.placesApi,
    this.mapboxSearch,
    this.storiesApi,
    this.photosApi,
    this.pickImageBytes,
    this.hasMapboxToken,
    this.mapBuilder,
    this.draftId,
  });

  final InviteGateway? inviteApi;
  final PeopleGateway? peopleApi;
  final PlacesGateway? placesApi;
  final MapboxSearchGateway? mapboxSearch;
  final StoriesGateway? storiesApi;
  final PhotosGateway? photosApi;

  /// Gallery picker override so widget tests never open the system picker.
  final Future<Uint8List?> Function()? pickImageBytes;

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
  PhotosGateway? _photosOverride;

  final _body = TextEditingController();

  String? _familyId;
  String? _storyId;
  var _loadingFamily = true;
  var _busy = false;
  var _showPublishBanner = false;
  var _highlightTimeframeForPhoto = false;
  var _picking = false;
  var _photoError = false;
  Uint8List? _pendingPhotoBytes;
  final List<Photo> _storyPhotos = [];
  final Map<String, Uint8List> _photoPreviews = {};

  DateTime? _timeframeStart;
  DateTime? _timeframeEnd;
  final List<Person> _selectedPeople = [];
  Place? _selectedPlace;
  String? _placeId;
  var _shellMapFailed = false;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PhotosGateway get _photos =>
      widget.photosApi ?? (_photosOverride ??= PhotosApi());

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
      setState(() => _familyId = id);
      final draftId = widget.draftId;
      if (draftId != null) {
        await _hydrateDraft(draftId);
      }
    } catch (_) {
      // Family lookup failed; keep an unbound empty form.
    } finally {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  Future<void> _hydrateDraft(String draftId) async {
    final Story story;
    try {
      story = await _stories.getStory(draftId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t load draft. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    final familyId = story.familyId;
    final decade = DecadeRange.containing(story.timeframeStart);
    setState(() {
      _storyId = story.id;
      _familyId = familyId;
      _timeframeStart = decade?.start ?? story.timeframeStart;
      _timeframeEnd = decade?.end ?? story.timeframeEnd;
      _body.text = story.body ?? '';
      _placeId = story.placeId;
      _shellMapFailed = !_tokenOk;
    });

    try {
      final people = await _people.listPeople(familyId);
      if (!mounted) return;
      setState(() {
        _selectedPeople
          ..clear()
          ..addAll(people.where((p) => story.personIds.contains(p.id)));
      });
    } catch (_) {
      // Story fields already applied; people chips stay empty.
    }

    final placeId = story.placeId;
    if (placeId != null && placeId.isNotEmpty) {
      try {
        final favorites = await _places.listFavorites(familyId);
        final recents = await _places.listRecents(familyId);
        Place? place;
        for (final candidate in [...favorites, ...recents]) {
          if (candidate.id == placeId) {
            place = candidate;
            break;
          }
        }
        if (!mounted) return;
        if (place != null) {
          setState(() => _selectedPlace = place);
        }
      } catch (_) {
        // Keep placeId even if favorites/recents lookup fails.
      }
    }

    try {
      final listed = await _photos.listPhotos(draftId);
      if (!mounted) return;
      final previews = <String, Uint8List>{};
      for (final photo in listed) {
        try {
          previews[photo.id] = await _photos.downloadBytes(photo.storagePath);
        } catch (_) {
          // Keep the tile; placeholder icon if bytes are missing.
        }
      }
      if (!mounted) return;
      setState(() {
        _storyPhotos
          ..clear()
          ..addAll(listed);
        _photoPreviews
          ..clear()
          ..addAll(previews);
      });
    } catch (_) {
      // Story fields already applied; photo strip stays empty.
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
      _highlightTimeframeForPhoto = false;
    });
    if (_pendingPhotoBytes != null) {
      _savePendingPhoto();
    }
  }

  void _clearHeldPhoto() {
    setState(() {
      _pendingPhotoBytes = null;
      _highlightTimeframeForPhoto = false;
    });
  }

  Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _onAddPhoto() async {
    if (_busy || _loadingFamily || _picking) return;
    if (_storyPhotos.length >= maxPhotosPerStory) return;
    // The browser only opens the file chooser in this click. Anything awaited
    // before pickImage spends the gesture, and the chooser never appears.
    final picker = widget.pickImageBytes ?? _pickFromGallery;
    _picking = true;
    Uint8List? bytes;
    try {
      bytes = await picker();
    } finally {
      _picking = false;
    }
    if (!mounted || bytes == null) return;
    _pendingPhotoBytes = bytes;
    if (_timeframeStart == null) {
      setState(() => _highlightTimeframeForPhoto = true);
      return;
    }
    await _savePendingPhoto();
  }

  Future<void> _savePendingPhoto() async {
    if (_busy || _pendingPhotoBytes == null || _timeframeStart == null) return;
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted || story == null) {
        if (mounted) setState(() => _photoError = true);
        return;
      }
      await _uploadPending();
    } catch (_) {
      if (mounted) setState(() => _photoError = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRetryPhoto() async {
    if (_busy || _pendingPhotoBytes == null) return;
    setState(() => _busy = true);
    try {
      if (_storyId == null) {
        final story = await _persistDraft();
        if (!mounted || story == null) {
          if (mounted) setState(() => _photoError = true);
          return;
        }
      }
      await _uploadPending();
    } catch (_) {
      if (mounted) setState(() => _photoError = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadPending() async {
    final bytes = _pendingPhotoBytes;
    final familyId = _familyId;
    final storyId = _storyId;
    if (bytes == null || familyId == null || storyId == null) return;
    try {
      final photo = await _photos.uploadPhoto(
        familyId: familyId,
        storyId: storyId,
        bytes: bytes,
        sortOrder: _storyPhotos.length,
      );
      if (!mounted) return;
      setState(() {
        _storyPhotos.add(photo);
        _photoPreviews[photo.id] = bytes;
        _photoError = false;
        _pendingPhotoBytes = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _photoError = true);
    }
  }

  Future<void> _onRemovePhoto(Photo photo) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _photos.deletePhoto(photo);
      if (!mounted) return;
      setState(() {
        _storyPhotos.removeWhere((p) => p.id == photo.id);
        _photoPreviews.remove(photo.id);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      final story = await _persistDraft();
      if (!mounted) return;
      if (story == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save draft. Try again.')),
      );
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t publish story. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _selectedPlace;

    return Scaffold(
      appBar: AlbumTopBar(
        screenLabel: 'New story',
        actions: [
          TextButton(
            onPressed: _canSaveDraft ? _onSaveDraft : null,
            child: const Text('Save draft'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _actionsEnabled ? _onPublish : null,
            child: const Text('Publish story'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: AlbumColumn(
          maxWidth: 1080,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showPublishBanner) ...[
                  const Text('Finish the highlighted fields to publish.'),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final storyColumn = _storyColumn();
                    final contextColumn = _contextColumn(place);
                    if (constraints.maxWidth < 680) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [storyColumn, contextColumn],
                      );
                    }
                    final contextWidth = constraints.maxWidth * 0.52;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: storyColumn),
                        const SizedBox(width: 24),
                        SizedBox(width: contextWidth, child: contextColumn),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storyColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _highlightIfMissing(
          missing: _showPublishBanner && !_readiness.hasBody,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x142C2416),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: TextField(
                controller: _body,
                minLines: 8,
                maxLines: null,
                cursorColor: albumTerracotta,
                onChanged: (_) => setState(() {}),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 22, height: 1.55),
                decoration: InputDecoration(
                  hintText: 'Write the story',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 22,
                    height: 1.55,
                    color: albumInk.withValues(alpha: 0.38),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x142C2416),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: albumTerracotta,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Photos & Keepsakes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Text(
                      '${_storyPhotos.length} of $maxPhotosPerStory added',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: albumInk.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PhotoStrip(
                  photos: _storyPhotos,
                  previews: _photoPreviews,
                  onAdd: _onAddPhoto,
                  onRemove: _onRemovePhoto,
                  onRetry: _onRetryPhoto,
                  uploadFailed: _photoError,
                  canAdd: _storyPhotos.length < maxPhotosPerStory,
                  columns: 3,
                  addLabel: 'Add photo',
                  addHint: 'Up to $maxPhotosPerStory photos',
                  heldPreview: _highlightTimeframeForPhoto
                      ? _pendingPhotoBytes
                      : null,
                  onClearHeld: _clearHeldPhoto,
                ),
                if (_highlightTimeframeForPhoto) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Choose a decade to keep this photo.',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: albumTerracotta),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contextColumn(Place? place) {
    final readiness = _readiness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _highlightIfMissing(
          missing:
              (_showPublishBanner && !readiness.hasTimeframe) ||
              (_highlightTimeframeForPhoto && _timeframeStart == null),
          child: _paperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeframe',
                  style: Theme.of(context).textTheme.titleSmall,
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
        ),
        _highlightIfMissing(
          missing: _showPublishBanner && !readiness.hasPerson,
          child: _paperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'People',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${_selectedPeople.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final person in _selectedPeople)
                      Chip(
                        label: Text(person.name),
                        labelStyle: Theme.of(context).textTheme.titleMedium,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
        ),
        _highlightIfMissing(
          missing: _showPublishBanner && !readiness.hasPlace,
          child: _placeCard(place),
        ),
      ],
    );
  }

  Widget _paperCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142C2416),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: child,
        ),
      ),
    );
  }

  Widget _placeCard(Place? place) {
    return _paperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Place', style: Theme.of(context).textTheme.titleSmall),
          if (place != null) ...[
            const SizedBox(height: 8),
            Text(place.label, style: Theme.of(context).textTheme.titleSmall),
            Text(place.address, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _buildSelectedPlaceMap(place),
          ],
          TextButton(
            onPressed: _actionsEnabled ? _openChoosePlace : null,
            child: const Text('Choose place'),
          ),
        ],
      ),
    );
  }

  Widget _highlightIfMissing({required bool missing, required Widget child}) {
    if (!missing) return child;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: albumTerracotta, width: 2),
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
      height: 200,
      onTileError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _shellMapFailed = true);
      },
    );
  }
}

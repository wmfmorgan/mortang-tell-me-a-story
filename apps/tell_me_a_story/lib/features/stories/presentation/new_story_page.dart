import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/photo.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/publish_readiness.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/env.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_modal_frame.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date_picker.dart';
import 'package:tell_me_a_story/features/people/presentation/add_person_modal.dart';
import 'package:tell_me_a_story/features/people/presentation/person_profile_dialog.dart';
import 'package:tell_me_a_story/features/places/presentation/place_map.dart';
import 'package:tell_me_a_story/features/places/presentation/place_picker_modal.dart';
import 'package:tell_me_a_story/features/stories/presentation/photo_strip.dart';

part 'new_story_page_cards.dart';

const _storyCardGap = 20.0;

/// Pause after the last keystroke before an autosave. Leaving the page does not wait.
const kAutosavePause = Duration(seconds: 2);

typedef _DraftRange = ({
  DateTime start,
  DateTime end,
  StoryDatePrecision precision,
});

/// Capture form for `/stories/new` — timeframe, people, place, title, body, persist.
class NewStoryPage extends ConsumerStatefulWidget {
  const NewStoryPage({
    super.key,
    this.pickImageBytes,
    this.hasMapboxToken,
    this.mapBuilder,
    this.draftId,
    this.editStoryId,
  });

  /// Gallery picker override so widget tests never open the system picker.
  final Future<Uint8List?> Function()? pickImageBytes;

  /// Defaults to [Env.hasMapboxToken] inside [PlacePickerModal].
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  /// Resume a draft via `/stories/new?draft=`.
  final String? draftId;

  /// Published or draft edit at `/stories/:storyId/edit`.
  final String? editStoryId;

  @override
  ConsumerState<NewStoryPage> createState() => _NewStoryPageState();
}

class _NewStoryPageState extends ConsumerState<NewStoryPage> {
  // Read once in initState: the leave-page autosave in dispose still needs them.
  late final InviteRepository _invite;
  late final PeopleRepository _people;
  late final PlacesRepository _places;
  late final StoriesRepository _stories;
  late final PhotosRepository _photos;

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _year = TextEditingController();

  String? _familyId;
  String? _storyId;
  Timer? _autosaveTimer;
  var _autosaveInserted = false;
  var _autosaveDirty = false;
  var _autosaveInFlight = false;
  var _autosaveCoalesce = false;
  var _autosaveStopped = false;
  String? _autosaveLabel;
  var _loadingFamily = true;
  var _busy = false;
  var _showPublishBanner = false;
  var _highlightTimeframeForPhoto = false;
  var _picking = false;
  var _photoError = false;
  Uint8List? _pendingPhotoBytes;
  final List<Photo> _storyPhotos = [];
  final Map<String, Uint8List> _photoPreviews = {};

  int? _month;
  int? _day;

  final List<Person> _selectedPeople = [];

  /// Linked ids hydrate could not show. While non-empty, saves leave story_people as is.
  final Set<String> _unloadedPersonIds = <String>{};
  Place? _selectedPlace;
  String? _placeId;
  var _shellMapFailed = false;

  late final UnsavedGuard _guard;
  _FormSnapshot? _snapshot;
  ValueKey<String>? _pageKey;
  var _disposed = false;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  bool get _editing => widget.editStoryId != null;

  StoryDate? get _storyDate =>
      storyDateFromFields(yearText: _year.text, month: _month, day: _day);

  PublishReadiness get _readiness => publishReadiness(
    title: _title.text,
    body: _body.text,
    timeframeStart: _storyDate?.toRange().start,
    personIds: [for (final p in _selectedPeople) p.id, ..._unloadedPersonIds],
    placeId: _selectedPlace?.id ?? _placeId,
  );

  bool get _actionsEnabled => !_loadingFamily && !_busy;

  bool get _canSaveDraft => _actionsEnabled && _storyDate != null;

  bool get _canSaveChanges => _actionsEnabled && _storyDate != null;

  List<String>? get _personIdsToWrite => _unloadedPersonIds.isEmpty
      ? [for (final p in _selectedPeople) p.id]
      : null;

  @override
  void initState() {
    super.initState();
    _invite = ref.read(inviteRepositoryProvider);
    _people = ref.read(peopleRepositoryProvider);
    _places = ref.read(placesRepositoryProvider);
    _stories = ref.read(storiesRepositoryProvider);
    _photos = ref.read(photosRepositoryProvider);
    _shellMapFailed = !_tokenOk;
    _guard = UnsavedGuard(
      exitPrompts: true,
      isDirty: _formDirty,
      save: () => _editing ? _saveChangesCore() : _saveDraftCore(),
      discard: _discardUnsaved,
    );
    if (widget.draftId == null && widget.editStoryId == null) {
      _snapshot = _captureSnapshot();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final key = GoRouterState.of(context).pageKey;
    final previous = _pageKey;
    if (previous == key) return;
    if (previous != null) UnsavedGuards.unregister(previous, _guard);
    _pageKey = key;
    UnsavedGuards.register(key, _guard);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_disposed) _guard.changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    if (!_editing && !_autosaveStopped && _autosaveDirty && _storyId != null) {
      unawaited(_runAutosave());
    }
    final pageKey = _pageKey;
    if (pageKey != null) UnsavedGuards.unregister(pageKey, _guard);
    _guard.dispose();
    _title.dispose();
    _body.dispose();
    _year.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    if (_editing || _autosaveStopped) return;
    _storyId ??= const Uuid().v4();
    _autosaveDirty = true;
    if (_autosaveInFlight) {
      _autosaveCoalesce = true;
      return;
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(kAutosavePause, () {
      unawaited(_runAutosave());
    });
  }

  Future<void> _runAutosave() async {
    if (_editing || _autosaveStopped) return;
    if (_autosaveInFlight) {
      _autosaveCoalesce = true;
      return;
    }
    if (!_autosaveDirty || _storyId == null) return;
    _autosaveInFlight = true;
    // Read the fields before the first await so dispose can still save.
    final form = _captureSnapshot();
    final range = _storyDate?.toRange();
    final personIds = _personIdsToWrite;
    try {
      final story = await _persistDraft(
        autosave: true,
        title: form.title,
        body: form.body,
        range: range,
        personIds: personIds,
        placeId: form.placeId,
      );
      _autosaveSucceeded(story, form);
    } catch (_) {
      // Mapped to the "Not saved" label; the next edit retries.
      _autosaveDirty = true;
      if (mounted) setState(() => _autosaveLabel = 'Not saved');
    } finally {
      _finishAutosave();
    }
  }

  void _autosaveSucceeded(Story? story, _FormSnapshot form) {
    if (_autosaveStopped) {
      if (mounted) setState(() => _autosaveLabel = null);
      return;
    }
    if (story != null && mounted) {
      _snapshot = form;
      setState(() => _autosaveLabel = 'Saved');
    }
  }

  void _finishAutosave() {
    _autosaveInFlight = false;
    if (_autosaveStopped || _disposed) {
      _autosaveCoalesce = false;
    } else if (_autosaveCoalesce) {
      _autosaveCoalesce = false;
      _autosaveDirty = true;
      unawaited(_runAutosave());
    }
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _invite.currentFamilyId();
      if (!mounted) return;
      setState(() => _familyId = id);
      final editId = widget.editStoryId;
      final draftId = widget.draftId;
      if (editId != null) {
        await _hydrateDraft(editId);
      } else if (draftId != null) {
        await _hydrateDraft(draftId);
      }
    } catch (_) {
      // Family lookup failed; keep an unbound empty form.
    } finally {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  Future<void> _hydrateDraft(String draftId) async {
    final story = await _loadStory(draftId);
    if (story == null || !mounted) return;
    _applyStory(story);
    await _hydratePeople(story);
    if (!mounted) return;
    final placeId = story.placeId;
    if (placeId != null && placeId.isNotEmpty) {
      await _hydratePlace(story.familyId, placeId);
      if (!mounted) return;
    }
    await _hydratePhotos(draftId);
    if (!mounted) return;
    _autosaveDirty = false;
    _autosaveCoalesce = false;
    _snapshot = _captureSnapshot();
  }

  Future<Story?> _loadStory(String draftId) async {
    try {
      return await _stories.getStory(draftId);
    } catch (_) {
      // Mapped to the load-failure snackbar.
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t load draft. Try again.')),
      );
      return null;
    }
  }

  void _applyStory(Story story) {
    final start = story.timeframeStart;
    final parsed = start == null
        ? null
        : StoryDate.fromRow(start, story.timeframeEnd, story.datePrecision);
    _year.text = parsed == null ? '' : '${parsed.year}';
    _autosaveInserted = true;
    setState(() {
      _storyId = story.id;
      _familyId = story.familyId;
      _month = parsed?.month;
      _day = parsed?.day;
      _title.text = story.title ?? '';
      _body.text = story.body ?? '';
      _placeId = story.placeId;
      _unloadedPersonIds
        ..clear()
        ..addAll(story.personIds);
      _shellMapFailed = !_tokenOk;
    });
  }

  Future<void> _hydratePeople(Story story) async {
    try {
      final people = await _people.listTreePeople(story.familyId);
      if (!mounted) return;
      final shown = people
          .where((p) => story.personIds.contains(p.id))
          .toList();
      final shownIds = {for (final p in shown) p.id};
      setState(() {
        _selectedPeople
          ..clear()
          ..addAll(shown);
        _unloadedPersonIds
          ..clear()
          ..addAll(story.personIds.toSet().difference(shownIds));
      });
    } catch (_) {
      // Story fields already applied; people chips stay empty.
      if (!mounted) return;
      setState(() {
        _unloadedPersonIds
          ..clear()
          ..addAll(story.personIds);
      });
    }
  }

  Future<void> _hydratePlace(String familyId, String placeId) async {
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

  Future<void> _hydratePhotos(String draftId) async {
    try {
      final listed = await _photos.listPhotos(draftId);
      if (!mounted) return;
      final previews = <String, Uint8List>{};
      for (final photo in listed) {
        try {
          previews[photo.id] = await _photos.downloadBytes(
            photo.effectiveStoragePath,
          );
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
      final added = await AddPersonModal.show(
        context,
        familyId: familyId,
        // Link only an inserted draft. Before the first insert the minted id
        // is not a story yet; the picked people ride along on the insert.
        storyId: _autosaveInserted ? _storyId : null,
        linkedPersonIds: {
          for (final person in _selectedPeople) person.id,
          ..._unloadedPersonIds,
        },
      );
      if (!mounted || added == null) return;
      setState(() {
        for (final person in added.people) {
          if (_selectedPeople.any((existing) => existing.id == person.id)) {
            continue;
          }
          _selectedPeople.add(person);
        }
      });
      _scheduleAutosave();
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

  void _onShellMapFailed() {
    if (!mounted) return;
    setState(() => _shellMapFailed = true);
  }

  void _onMonth(int? month) {
    setState(() {
      _month = month;
      if (month == null) _day = null;
      _highlightTimeframeForPhoto = false;
    });
  }

  void _onDay(int? day) {
    setState(() {
      _day = day;
      _highlightTimeframeForPhoto = false;
    });
  }

  void _onYearChanged() {
    setState(() => _highlightTimeframeForPhoto = false);
  }

  void _onTextChanged(String _) {
    setState(() {});
    _scheduleAutosave();
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
    if (_storyDate == null) {
      setState(() => _highlightTimeframeForPhoto = true);
      return;
    }
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
    await _savePendingPhoto();
  }

  Future<void> _savePendingPhoto() async {
    if (_busy || _pendingPhotoBytes == null || _storyDate == null) return;
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted || story == null) {
        if (mounted) setState(() => _photoError = true);
        return;
      }
      await _uploadPending();
    } catch (_) {
      // Mapped to the photo strip's upload-failed state.
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
      // Mapped to the photo strip's upload-failed state.
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
      // Mapped to the photo strip's upload-failed state.
      if (!mounted) return;
      setState(() => _photoError = true);
    }
  }

  Future<void> _onToggleHero(Photo photo) async {
    final storyId = _storyId;
    if (_busy || storyId == null || _storyPhotos.isEmpty) return;
    final sorted = [..._storyPhotos]..sort(comparePhotoOrder);
    final hero = sorted.first;
    // The filled star is already the hero. Tapping it does not reorder.
    if (photo.id == hero.id) return;
    final current = [..._storyPhotos];
    setState(() => _busy = true);
    try {
      await _photos.setHeroPhoto(storyId: storyId, photoId: photo.id);
      if (!mounted) return;
      final updated = photosWithHeroFirst(current, photo.id);
      setState(() {
        _storyPhotos
          ..clear()
          ..addAll(updated);
      });
    } catch (_) {
      // Mapped to the photo strip's upload-failed state.
      if (!mounted) return;
      setState(() => _photoError = true);
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<Story?> _persistDraft({
    bool autosave = false,
    String? title,
    String? body,
    _DraftRange? range,
    List<String>? personIds,
    String? placeId,
  }) async {
    _autosaveDirty = false;
    final familyId = await _ensureFamilyId();
    final date = _storyDate;
    if (familyId == null) {
      if (autosave) throw StateError('no family');
      return null;
    }
    if (!autosave && date == null) return null;
    final resolvedRange = range ?? date?.toRange();
    if (!autosave && resolvedRange == null && !_autosaveInserted) return null;
    final story = await _writeDraft(
      _DraftSnapshot(
        id: _storyId,
        familyId: familyId,
        start: resolvedRange?.start,
        end: resolvedRange?.end,
        precision: resolvedRange?.precision.name,
        title: title ?? _title.text,
        body: body ?? _body.text,
        placeId: placeId ?? _selectedPlace?.id ?? _placeId,
        personIds: personIds ?? _personIdsToWrite,
      ),
      autosave: autosave,
    );
    if (story != null && mounted) setState(() => _storyId = story.id);
    return story;
  }

  Future<Story?> _writeDraft(
    _DraftSnapshot snapshot, {
    bool autosave = false,
  }) async {
    if (!_autosaveInserted) {
      if (!autosave && snapshot.start == null) return null;
      return _insertDraft(snapshot, autosave: autosave);
    }
    // Non-null: _autosaveInserted is only set together with _storyId.
    final storyId = _storyId!;
    if (autosave) return _autosaveExisting(storyId, snapshot);
    final updated = await _stories.updateDraft(
      storyId: storyId,
      timeframeStart: snapshot.start,
      timeframeEnd: snapshot.end,
      datePrecision: snapshot.precision,
      title: snapshot.title,
      body: snapshot.body,
      placeId: snapshot.placeId,
      personIds: snapshot.personIds,
    );
    _storyId = updated.id;
    return updated;
  }

  Future<Story> _insertDraft(
    _DraftSnapshot snapshot, {
    required bool autosave,
  }) async {
    final created = await _stories.createDraft(
      id: snapshot.id,
      allowUndated: autosave,
      familyId: snapshot.familyId,
      timeframeStart: snapshot.start,
      timeframeEnd: snapshot.end,
      datePrecision: snapshot.precision,
      title: snapshot.title,
      body: snapshot.body,
      placeId: snapshot.placeId,
      personIds: snapshot.personIds ?? const [],
    );
    _autosaveInserted = true;
    _storyId = created.id;
    return created;
  }

  Future<Story?> _autosaveExisting(
    String storyId,
    _DraftSnapshot snapshot,
  ) async {
    final wrote = await _stories.autosaveDraft(
      storyId: storyId,
      timeframeStart: snapshot.start,
      timeframeEnd: snapshot.end,
      datePrecision: snapshot.precision,
      title: snapshot.title,
      body: snapshot.body,
      placeId: snapshot.placeId,
      personIds: snapshot.personIds,
    );
    if (!wrote) {
      _autosaveStopped = true;
      _autosaveTimer?.cancel();
      return null;
    }
    return Story(
      id: storyId,
      familyId: snapshot.familyId,
      authorId: '',
      title: snapshot.title,
      body: snapshot.body,
      timeframeStart: snapshot.start,
      status: StoryStatus.draft,
      personIds: snapshot.personIds ?? const [],
    );
  }

  Future<bool> _saveDraftCore() async {
    if (!_canSaveDraft) return false;
    _autosaveTimer?.cancel();
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted || story == null) return false;
      _markSaved();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved')));
      _clearNewTimelineFrom();
      return true;
    } catch (_) {
      // Mapped to the save-failure snackbar.
      if (!mounted) return false;
      _showSaveFailed();
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _markSaved() {
    _autosaveDirty = false;
    _autosaveCoalesce = false;
    _snapshot = _captureSnapshot();
  }

  void _showSaveFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn’t save draft. Try again.')),
    );
  }

  Future<void> _onSaveDraft() async {
    await _saveDraftCore();
  }

  void _clearNewTimelineFrom() {
    final router = GoRouter.maybeOf(context);
    if (router == null || !mounted) return;
    final uri = GoRouterState.of(context).uri;
    if (!uri.queryParameters.containsKey('newTimelineFrom')) return;
    final params = Map<String, String>.from(uri.queryParameters)
      ..remove('newTimelineFrom');
    final storyId = _storyId;
    final keptDraft = params['draft'];
    if (storyId != null &&
        storyId.isNotEmpty &&
        (keptDraft == null || keptDraft.isEmpty)) {
      params['draft'] = storyId;
    }
    router.go(uri.replace(queryParameters: params).toString());
  }

  void _returnToReader(bool saved) {
    final id = _storyId ?? widget.editStoryId;
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        navigator.pop(saved);
      }
      return;
    }
    if (router.canPop()) {
      router.pop(saved);
      return;
    }
    if (id != null && id.isNotEmpty) {
      router.pushReplacement(AppRoutes.storyPath(id));
    }
  }

  Future<bool> _saveChangesCore() async {
    if (!_canSaveChanges) return false;
    _autosaveTimer?.cancel();
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted || story == null) return false;
      _markSaved();
      return true;
    } catch (_) {
      // Mapped to the save-failure snackbar.
      if (!mounted) return false;
      _showSaveFailed();
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSaveChanges() async {
    final saved = await _saveChangesCore();
    if (!saved || !mounted) return;
    _guard.skipNextPrompt();
    _returnToReader(true);
  }

  Future<void> _onPublish() async {
    if (!_actionsEnabled) return;
    _autosaveTimer?.cancel();
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
      _leaveAfterPublish(story.id);
    } catch (_) {
      // Mapped to the publish-failure snackbar.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t publish story. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leaveAfterPublish(String storyId) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _guard.skipNextPrompt();
    final from = GoRouterState.of(context)
        .uri
        .queryParameters['newTimelineFrom'];
    if (from != null && from.isNotEmpty) {
      context.go('${AppRoutes.timeline}?newTimelineOrigin=$storyId');
    } else {
      context.pushReplacement(AppRoutes.storyPath(storyId));
    }
  }

  VoidCallback? get _primaryAction {
    if (!_actionsEnabled) return null;
    if (!_editing) return _onPublish;
    return _canSaveChanges ? _onSaveChanges : null;
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedGuardScope(
      guard: _guard,
      child: ListenableBuilder(
        listenable: _guard,
        builder: (context, _) => PopScope(
          canPop: !_formDirty(),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_confirmBlockedPop());
          },
          child: AlbumModalFrame(
            frameKey: const Key('story-capture-modal'),
            label: _editing ? 'EDIT' : 'STORY',
            trailing: _CaptureActions(
              editing: _editing,
              autosaveLabel: _autosaveLabel,
              onSaveDraft: !_actionsEnabled || !_canSaveDraft
                  ? null
                  : _onSaveDraft,
              onPrimary: _primaryAction,
            ),
            child: _CaptureBody(
              editing: _editing,
              showPublishBanner: _showPublishBanner,
              story: _storyColumn(),
              details: _contextColumn(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlockedPop() async {
    final leave = await _guard.confirmLeave(context);
    if (!leave || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GoRouter.of(context).pop();
    });
  }

  bool _formDirty() {
    final snap = _snapshot;
    if (snap == null) return false;
    final fieldsDiffer = !snap.matches(
      title: _title.text,
      body: _body.text,
      year: _year.text,
      month: _month,
      day: _day,
      placeId: _selectedPlace?.id ?? _placeId,
      people: _selectedPeople,
    );
    if (_editing) return fieldsDiffer;
    return _autosaveDirty || _autosaveCoalesce || fieldsDiffer;
  }

  _FormSnapshot _captureSnapshot() {
    return _FormSnapshot(
      title: _title.text,
      body: _body.text,
      year: _year.text,
      month: _month,
      day: _day,
      placeId: _selectedPlace?.id ?? _placeId,
      place: _selectedPlace,
      people: List<Person>.from(_selectedPeople),
    );
  }

  void _discardUnsaved() {
    _autosaveTimer?.cancel();
    _autosaveDirty = false;
    _autosaveCoalesce = false;
    final snap = _snapshot;
    if (snap == null) return;
    _title.text = snap.title;
    _body.text = snap.body;
    _year.text = snap.year;
    setState(() {
      _month = snap.month;
      _day = snap.day;
      _placeId = snap.placeId;
      _selectedPlace = snap.place;
      _selectedPeople
        ..clear()
        ..addAll(snap.people);
    });
  }

  _StoryColumn _storyColumn() {
    final readiness = _readiness;
    return _StoryColumn(
      title: _title,
      body: _body,
      titleMissing: _showPublishBanner && !readiness.hasTitle,
      bodyMissing: _showPublishBanner && !readiness.hasBody,
      onTextChanged: _onTextChanged,
      photos: _PhotosCard(
        photos: _storyPhotos,
        previews: _photoPreviews,
        uploadFailed: _photoError,
        dated: _storyDate != null,
        showTimeframeHint: _highlightTimeframeForPhoto && _storyDate == null,
        onAdd: _onAddPhoto,
        onRemove: _onRemovePhoto,
        onToggleHero: _onToggleHero,
        onRetry: _onRetryPhoto,
      ),
    );
  }

  _ContextColumn _contextColumn() {
    final readiness = _readiness;
    return _ContextColumn(
      timeframeMissing:
          (_showPublishBanner && !readiness.hasTimeframe) ||
          (_highlightTimeframeForPhoto && _storyDate == null),
      peopleMissing: _showPublishBanner && !readiness.hasPerson,
      placeMissing: _showPublishBanner && !readiness.hasPlace,
      timeframe: StoryDatePicker(
        year: _year,
        month: _month,
        day: _day,
        onMonth: _onMonth,
        onDay: _onDay,
        onYearChanged: _onYearChanged,
      ),
      people: _PeopleCardBody(
        people: _selectedPeople,
        canRemove: _unloadedPersonIds.isEmpty,
        onRemove: _removePerson,
        onAdd: _actionsEnabled ? _openAddPerson : null,
      ),
      place: _PlaceCardBody(
        place: _selectedPlace,
        mapFailed: _shellMapFailed || !_tokenOk,
        mapBuilder: widget.mapBuilder,
        onRetryMap: _retryShellMap,
        onMapFailed: _onShellMapFailed,
        onChoose: _actionsEnabled ? _openChoosePlace : null,
      ),
    );
  }
}

class _DraftSnapshot {
  const _DraftSnapshot({
    required this.id,
    required this.familyId,
    required this.start,
    required this.end,
    required this.precision,
    required this.title,
    required this.body,
    required this.placeId,
    required this.personIds,
  });

  final String? id;
  final String familyId;
  final DateTime? start;
  final DateTime? end;
  final String? precision;
  final String title;
  final String body;
  final String? placeId;
  final List<String>? personIds;
}

class _FormSnapshot {
  const _FormSnapshot({
    required this.title,
    required this.body,
    required this.year,
    required this.month,
    required this.day,
    required this.placeId,
    required this.place,
    required this.people,
  });

  final String title;
  final String body;
  final String year;
  final int? month;
  final int? day;
  final String? placeId;
  final Place? place;
  final List<Person> people;

  bool matches({
    required String title,
    required String body,
    required String year,
    required int? month,
    required int? day,
    required String? placeId,
    required List<Person> people,
  }) {
    if (this.title != title ||
        this.body != body ||
        this.year != year ||
        this.month != month ||
        this.day != day ||
        this.placeId != placeId) {
      return false;
    }
    final live = people.map((person) => person.id).toSet();
    final saved = this.people.map((person) => person.id).toSet();
    return live.length == saved.length && live.containsAll(saved);
  }
}

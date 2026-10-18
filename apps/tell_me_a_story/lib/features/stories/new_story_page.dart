import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/mapbox_search.dart';
import '../../data/people_api.dart';
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/stories_api.dart';
import '../people/add_person_modal.dart';
import '../people/person_profile_dialog.dart';
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';
import 'photo_strip.dart';
import 'story_date.dart';
import 'story_date_picker.dart';

const _storyCardGap = 20.0;

/// Pause after the last keystroke before an autosave. Leaving the page does not wait.
const kAutosavePause = Duration(seconds: 2);

/// Capture form for `/stories/new` — timeframe, people, place, title, body, persist.
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
    this.editStoryId,
    this.familiesApi,
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

  /// Published or draft edit at `/stories/:storyId/edit`.
  final String? editStoryId;

  final FamiliesGateway? familiesApi;

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

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _year = TextEditingController();

  String? _familyId;
  String? _menuFamilyId;
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
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

  /// Decade-dated row loaded for edit. The year box stays empty. Saving the
  /// same year leaves the decade in place.
  StoryDate? _loadedLegacy;
  final List<Person> _selectedPeople = [];
  Place? _selectedPlace;
  String? _placeId;
  var _shellMapFailed = false;

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PhotosGateway get _photos =>
      widget.photosApi ?? (_photosOverride ??= PhotosApi());

  bool get _editing => widget.editStoryId != null;

  StoryDate? get _storyDate =>
      storyDateFromFields(yearText: _year.text, month: _month, day: _day);

  PublishReadiness get _readiness => publishReadiness(
    title: _title.text,
    body: _body.text,
    timeframeStart: _storyDate?.toRange().start,
    personIds: _selectedPeople.map((p) => p.id),
    placeId: _selectedPlace?.id ?? _placeId,
  );

  bool get _actionsEnabled => !_loadingFamily && !_busy;

  bool get _canSaveDraft => _actionsEnabled && _storyDate != null;

  bool get _canSaveChanges => _actionsEnabled && _storyDate != null;

  /// True when the boxes differ from a loaded decade row, or this is any other story.
  bool get _shouldWriteDate {
    final date = _storyDate;
    if (date == null) return false;
    final legacy = _loadedLegacy;
    if (legacy == null) return true;
    return date.year != legacy.year || date.month != null || date.day != null;
  }

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
    _autosaveTimer?.cancel();
    if (!_editing && !_autosaveStopped && _autosaveDirty && _storyId != null) {
      unawaited(_runAutosave());
    }
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
    final title = _title.text;
    final body = _body.text;
    final range = _storyDate?.toRange();
    final personIds = _selectedPeople.map((person) => person.id).toList();
    final placeId = _selectedPlace?.id ?? _placeId;
    try {
      final story = await _persistDraft(
        autosave: true,
        title: title,
        body: body,
        range: range,
        personIds: personIds,
        placeId: placeId,
      );
      if (_autosaveStopped) {
        if (mounted) setState(() => _autosaveLabel = null);
        return;
      }
      if (story != null && mounted) setState(() => _autosaveLabel = 'Saved');
    } catch (_) {
      _autosaveDirty = true;
      if (mounted) setState(() => _autosaveLabel = 'Not saved');
    } finally {
      _autosaveInFlight = false;
      if (_autosaveStopped) {
        _autosaveCoalesce = false;
      } else if (_autosaveCoalesce) {
        _autosaveCoalesce = false;
        _autosaveDirty = true;
        unawaited(_runAutosave());
      }
    }
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _invite.currentFamilyId();
      if (!mounted) return;
      setState(() => _familyId = id);
      await _loadFamilies();
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
    final start = story.timeframeStart;
    final parsed = start == null
        ? null
        : StoryDate.fromRow(start, story.timeframeEnd, story.datePrecision);
    final legacy = parsed?.legacyDecade ?? false;
    // A decade row opens with an empty year, including edit.
    final keepDecadeBlank = legacy;
    _year.text = parsed == null || keepDecadeBlank ? '' : '${parsed.year}';
    _autosaveInserted = true;
    setState(() {
      _storyId = story.id;
      _familyId = familyId;
      _loadedLegacy = legacy && _editing ? parsed : null;
      _month = parsed == null || legacy ? null : parsed.month;
      _day = parsed == null || legacy ? null : parsed.day;
      _title.text = story.title ?? '';
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
      final added = await AddPersonModal.show(
        context,
        familyId: familyId,
        api: _people,
        invites: _invite,
        storyId: _storyId,
        linkedPersonIds: {for (final person in _selectedPeople) person.id},
        linkPerson: ({required String storyId, required String personId}) {
          return _stories.linkPerson(storyId: storyId, personId: personId);
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

  Future<Story?> _persistDraft({
    bool autosave = false,
    String? title,
    String? body,
    ({DateTime start, DateTime end, StoryDatePrecision precision})? range,
    List<String>? personIds,
    String? placeId,
  }) async {
    _autosaveDirty = false;
    final familyId = await _ensureFamilyId();
    final date = _storyDate;
    final keepLegacy = !_shouldWriteDate && _loadedLegacy != null;
    if (familyId == null) {
      if (autosave) throw StateError('no family');
      return null;
    }
    if (!autosave && (date == null && !keepLegacy)) return null;
    final resolvedRange = range ?? (_shouldWriteDate ? date?.toRange() : null);
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
        personIds: personIds ?? _selectedPeople.map((p) => p.id).toList(),
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
      try {
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
          personIds: snapshot.personIds,
        );
        _autosaveInserted = true;
        _storyId = created.id;
        return created;
      } on PostgrestException catch (error) {
        if (snapshot.id == null || !isDuplicateStoryKey(error)) rethrow;
        _autosaveInserted = true;
      }
    }
    if (autosave) {
      final wrote = await _stories.autosaveDraft(
        storyId: _storyId!,
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
        _autosaveLabel = null;
        return null;
      }
      return Story(
        id: _storyId!,
        familyId: snapshot.familyId,
        authorId: '',
        title: snapshot.title,
        body: snapshot.body,
        timeframeStart: snapshot.start,
        status: StoryStatus.draft,
        personIds: snapshot.personIds,
      );
    }
    final updated = await _stories.updateDraft(
      storyId: _storyId!,
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

  Future<void> _onSaveDraft() async {
    if (!_canSaveDraft) return;
    _autosaveTimer?.cancel();
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted) return;
      if (story == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved')));
      _clearNewTimelineFrom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save draft. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    if (context.canPop()) {
      context.pop(saved);
      return;
    }
    if (id != null && id.isNotEmpty) {
      context.go(AppRoutes.storyPath(id));
    }
  }

  void _onCancel() {
    if (!_actionsEnabled) return;
    _returnToReader(false);
  }

  Future<void> _onSaveChanges() async {
    if (!_canSaveChanges) return;
    _autosaveTimer?.cancel();
    setState(() => _busy = true);
    try {
      final story = await _persistDraft();
      if (!mounted || story == null) return;
      _returnToReader(true);
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
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        final from = GoRouterState.of(context)
            .uri
            .queryParameters['newTimelineFrom'];
        if (from != null && from.isNotEmpty) {
          context.go('${AppRoutes.timeline}?newTimelineOrigin=${story.id}');
        } else {
          context.go(AppRoutes.timeline);
        }
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

  Future<void> _loadFamilies() async {
    List<MemberFamily> rows = const [];
    List<StewardFamily> stewarded = const [];
    try {
      if (widget.familiesApi != null) {
        rows = await widget.familiesApi!.listMine();
        stewarded = await widget.familiesApi!.listStewarded();
      } else if (widget.inviteApi != null || widget.storiesApi != null) {
        final id = _familyId;
        if (id != null) {
          rows = [
            MemberFamily(id: id, name: 'Family', createdAt: DateTime.utc(2020)),
          ];
        }
      } else {
        final live = FamiliesApi();
        rows = await live.listMine();
        stewarded = await live.listStewarded();
      }
    } catch (_) {
      rows = const [];
      stewarded = const [];
    }
    if (!mounted) return;
    setState(() {
      _families = rows;
      _stewarded = stewarded;
    });
  }

  void _selectFamily(String id) {
    FamilySelection.remember(id);
    setState(() => _menuFamilyId = id);
  }

  String get _shownFamilyId => _menuFamilyId ?? _familyId ?? '';

  String get _familyName {
    for (final family in _families) {
      if (family.id == _shownFamilyId) return family.name;
    }
    return 'Family';
  }

  @override
  Widget build(BuildContext context) {
    final place = _selectedPlace;

    return Scaffold(
      appBar: AlbumHeader(
        page: AlbumHeaderPage.capture,
        familyName: _familyName,
        families: _families,
        currentFamilyId: _shownFamilyId,
        onFamilySelected: _selectFamily,
        stewarded: _stewarded,
        onSaveDraft: !_actionsEnabled
            ? null
            : (_editing ? _onCancel : (_canSaveDraft ? _onSaveDraft : null)),
        onPublish: !_actionsEnabled
            ? null
            : (_editing
                  ? (_canSaveChanges ? _onSaveChanges : null)
                  : _onPublish),
        captureStatus: _editing ? null : _autosaveLabel,
        captureSecondaryLabel: _editing ? 'Cancel' : 'Save draft',
        capturePrimaryLabel: _editing ? 'Save changes' : 'Publish story',
      ),
      body: SafeArea(
        child: AlbumColumn(
          maxWidth: 720,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_editing) ...[
                  Text(
                    'Edit story',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showPublishBanner) ...[
                  const Text('Finish the highlighted fields to publish.'),
                  const SizedBox(height: 12),
                ],
                _storyColumn(),
                const SizedBox(height: _storyCardGap),
                _contextColumn(place),
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
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _highlightIfMissing(
                  missing: _showPublishBanner && !_readiness.hasTitle,
                  child: TextField(
                    key: const Key('story-title'),
                    controller: _title,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: albumTerracotta,
                    onChanged: (_) {
                      setState(() {});
                      _scheduleAutosave();
                    },
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Give your memory a title...',
                      hintStyle: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: 30,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: albumInk.withValues(alpha: 0.38),
                          ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: albumTerracotta),
                      ),
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _highlightIfMissing(
                  missing: _showPublishBanner && !_readiness.hasBody,
                  child: TextField(
                    key: const Key('story-body'),
                    controller: _body,
                    minLines: 8,
                    maxLines: null,
                    cursorColor: albumTerracotta,
                    onChanged: (_) {
                      setState(() {});
                      _scheduleAutosave();
                    },
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontSize: 22, height: 1.55),
                    decoration: InputDecoration(
                      hintText: 'Write the story',
                      hintStyle: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(
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
              ],
            ),
          ),
        ),
        const SizedBox(height: _storyCardGap),
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
                  addEnabled: _storyDate != null,
                ),
                if (_highlightTimeframeForPhoto && _storyDate == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'A Timeframe is required before adding a photo.',
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
              (_highlightTimeframeForPhoto && _storyDate == null),
          child: _paperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeframe',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                StoryDatePicker(
                  year: _year,
                  month: _month,
                  day: _day,
                  onMonth: _onMonth,
                  onDay: _onDay,
                  onYearChanged: _onYearChanged,
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
                      PersonNamePill(
                        personId: person.id,
                        name: person.name,
                        people: _people,
                        invites: _invite,
                        child: Chip(
                          label: Text(person.name),
                          labelStyle: Theme.of(context).textTheme.titleMedium,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          onDeleted: () => _removePerson(person),
                        ),
                      ),
                    TextButton(
                      onPressed: _actionsEnabled ? _openAddPerson : null,
                      child: const PlusLabel(label: 'Add person'),
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
      padding: const EdgeInsets.only(bottom: _storyCardGap),
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
  final List<String> personIds;
}

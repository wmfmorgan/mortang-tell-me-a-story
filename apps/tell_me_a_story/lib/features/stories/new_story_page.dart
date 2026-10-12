import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
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
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';
import 'photo_strip.dart';
import 'story_date.dart';
import 'story_date_picker.dart';

const _storyOutline = Color(0xFFB9B0AD);
const _storyBlush = Color(0xFFF5DED6);
const _storyLow = Color(0xFFFAF2F0);
const _storyMuted = Color(0xFF655E5B);
const _storyHigh = Color(0xFFF0E6E3);

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

  /// Decade-dated row. The year box shows that decade's start year so it can
  /// be edited. Save leaves the decade in place until the year, month, or day
  /// changes.
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

  /// Edit of a decade-dated story can save title and body before the date changes.
  bool get _canSaveChanges =>
      _actionsEnabled &&
      (_storyDate != null || (_editing && _loadedLegacy != null));

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
    _title.dispose();
    _body.dispose();
    _year.dispose();
    super.dispose();
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
    final parsed = StoryDate.fromRow(
      story.timeframeStart,
      story.timeframeEnd,
      story.datePrecision,
    );
    final legacy = parsed.legacyDecade;
    // Draft capture still opens a decade row empty. Edit shows the decade's
    // start year so it can be changed, and shows any month and day.
    final keepDecadeBlank = legacy && !_editing;
    _year.text = keepDecadeBlank ? '' : '${parsed.year}';
    setState(() {
      _storyId = story.id;
      _familyId = familyId;
      _loadedLegacy = legacy && _editing ? parsed : null;
      _month = legacy ? null : parsed.month;
      _day = legacy ? null : parsed.day;
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

  Future<Story?> _persistDraft() async {
    final familyId = await _ensureFamilyId();
    final date = _storyDate;
    final keepLegacy = !_shouldWriteDate && _loadedLegacy != null;
    if (!mounted || familyId == null || (date == null && !keepLegacy)) {
      return null;
    }
    final range = _shouldWriteDate ? date?.toRange() : null;
    final personIds = _selectedPeople.map((p) => p.id).toList();
    final placeId = _selectedPlace?.id ?? _placeId;
    final title = _title.text;
    final body = _body.text;
    final existingId = _storyId;
    if (existingId == null) {
      if (range == null) return null;
      final created = await _stories.createDraft(
        familyId: familyId,
        timeframeStart: range.start,
        timeframeEnd: range.end,
        datePrecision: range.precision.name,
        title: title,
        body: body,
        placeId: placeId,
        personIds: personIds,
      );
      if (!mounted) return created;
      setState(() => _storyId = created.id);
      return created;
    }
    final story = await _stories.updateDraft(
      storyId: existingId,
      timeframeStart: range?.start,
      timeframeEnd: range?.end,
      datePrecision: range?.precision.name,
      title: title,
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

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
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
        captureSecondaryLabel: _editing ? 'Cancel' : 'Save draft',
        capturePrimaryLabel: _editing ? 'Save changes' : 'Publish story',
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _editing ? 'Edit story' : 'New story',
                    style: GoogleFonts.newsreader(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: albumInk,
                    ),
                  ),
                  if (_showPublishBanner) ...[
                    const SizedBox(height: 12),
                    const Text('Finish the highlighted fields to publish.'),
                  ],
                  const SizedBox(height: 24),
                  _storyCard(),
                  const SizedBox(height: 24),
                  _photosCard(),
                  const SizedBox(height: 32),
                  _timeframeCard(),
                  const SizedBox(height: 32),
                  _peopleCard(),
                  const SizedBox(height: 32),
                  _placeCard(place),
                  const SizedBox(height: 24),
                  _privacyFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _storyCard() {
    final words = _wordCount(_body.text);
    final titleStyle = GoogleFonts.newsreader(
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: albumInk,
    );
    return _sectionCard(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: albumTerracotta, size: 18),
              const SizedBox(width: 8),
              Text(
                'STORY ENTRY',
                style: GoogleFonts.sourceSans3(
                  color: albumTerracotta,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _highlightIfMissing(
            missing: _showPublishBanner && !_readiness.hasTitle,
            child: TextField(
              key: const Key('story-title'),
              controller: _title,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: albumTerracotta,
              onChanged: (_) => setState(() {}),
              style: titleStyle,
              decoration: InputDecoration(
                hintText: 'Story title...',
                hintStyle: titleStyle.copyWith(color: _storyOutline),
                border: InputBorder.none,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: _storyOutline.withValues(alpha: 0.2),
                  ),
                ),
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
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.literata(
                fontSize: 16,
                height: 1.6,
                color: albumInk.withValues(alpha: 0.9),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _storyOutline.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  words == 1 ? '1 word' : '$words words',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    color: const Color(0xFF817976),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _storyLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 14, color: _storyMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Visible to immediate family',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 12,
                          color: _storyMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photosCard() {
    return _sectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photos & Keepsakes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: albumInk,
                  ),
                ),
              ),
              Text(
                '${_storyPhotos.length} of $maxPhotosPerStory added',
                style: GoogleFonts.sourceSans3(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: albumTerracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
    );
  }

  Widget _timeframeCard() {
    final readiness = _readiness;
    return _highlightIfMissing(
      missing:
          (_showPublishBanner && !readiness.hasTimeframe) ||
          (_highlightTimeframeForPhoto && _storyDate == null),
      child: _sectionCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBadge(Icons.schedule),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'When did this happen?',
                        style: GoogleFonts.newsreader(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: albumInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add the approximate or exact date',
                        style: GoogleFonts.literata(
                          fontSize: 14,
                          color: _storyMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StoryDatePicker(
              year: _year,
              month: _month,
              day: _day,
              onMonth: _onMonth,
              onDay: _onDay,
              onYearChanged: _onYearChanged,
            ),
            if (_loadedLegacy != null && !_shouldWriteDate) ...[
              const SizedBox(height: 8),
              Text(
                'Saved as the ${storyDateLabel(_loadedLegacy!)}. Change the year, or add a month and day.',
                key: const Key('story-date-legacy'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _peopleCard() {
    final count = _selectedPeople.length;
    return _highlightIfMissing(
      missing: _showPublishBanner && !_readiness.hasPerson,
      child: _sectionCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconBadge(Icons.group),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'People in this story',
                    style: GoogleFonts.newsreader(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: albumInk,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _storyBlush.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count tagged',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: albumTerracotta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final person in _selectedPeople)
                  Chip(
                    label: Text(
                      person.name,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5E4E48),
                      ),
                    ),
                    backgroundColor: _storyBlush,
                    side: BorderSide(
                      color: albumTerracotta.withValues(alpha: 0.2),
                    ),
                    shape: const StadiumBorder(),
                    deleteIcon: const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF5E4E48),
                    ),
                    onDeleted: _actionsEnabled
                        ? () => _removePerson(person)
                        : null,
                  ),
                TextButton(
                  onPressed: _actionsEnabled ? _openAddPerson : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _storyMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    side: BorderSide(
                      color: _storyOutline.withValues(alpha: 0.9),
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Add person',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required EdgeInsets padding, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _storyOutline.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _iconBadge(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _storyBlush.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: albumTerracotta, size: 24),
    );
  }

  Widget _placeCard(Place? place) {
    final placeLabel = place == null ? 'Choose place' : 'Change place';
    return _highlightIfMissing(
      missing: _showPublishBanner && !_readiness.hasPlace,
      child: _sectionCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _iconBadge(Icons.location_on),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Place & Setting',
                    style: GoogleFonts.newsreader(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: albumInk,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _actionsEnabled ? _openChoosePlace : null,
                  style: TextButton.styleFrom(
                    foregroundColor: albumTerracotta,
                    textStyle: GoogleFonts.sourceSans3(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(placeLabel),
                ),
              ],
            ),
            if (place != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _storyLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF817976).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'LOCATION',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: _storyMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        place.address.isEmpty ? place.label : place.address,
                        style: GoogleFonts.literata(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: albumInk,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit location',
                      onPressed: _actionsEnabled ? _openChoosePlace : null,
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: _storyMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (place.label.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  place.label,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: albumInk,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildSelectedPlaceMap(place),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _privacyFooter() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _storyHigh.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _storyOutline.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 16, color: albumTerracotta),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "Drafts stay private until you publish. Only you edit this story's core.",
                style: GoogleFonts.literata(fontSize: 12, color: _storyMuted),
              ),
            ),
          ],
        ),
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
      height: 256,
      onTileError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _shellMapFailed = true);
      },
    );
  }
}

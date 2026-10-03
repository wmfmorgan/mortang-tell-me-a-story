import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../data/comments_api.dart';
import '../../data/people_api.dart';
import '../../data/perspectives_api.dart' hide displayNameOrMember;
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/stories_api.dart';
import '../comments/comment_composer.dart';
import '../perspectives/add_perspective_page.dart';
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';
import 'photo_strip.dart';
import 'timeframe_chips.dart';

/// First non-empty line of [body], else `Untitled`. Does not use `stories.title`.
String storyHeadline(String? body) {
  for (final line in (body ?? '').split('\n')) {
    final t = line.trim();
    if (t.isNotEmpty) return t;
  }
  return 'Untitled';
}

/// Body after the lead line. A one-line story is only the lead.
String storyBodyRest(String? body) {
  final lines = (body ?? '').split('\n');
  var skippedLead = false;
  final rest = <String>[];
  for (final line in lines) {
    if (!skippedLead && line.trim().isNotEmpty) {
      skippedLead = true;
      continue;
    }
    if (skippedLead) rest.add(line);
  }
  return rest.join('\n').trim();
}

/// Published-only reader at `/stories/:storyId`.
class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({
    super.key,
    required this.storyId,
    this.storiesApi,
    this.peopleApi,
    this.placesApi,
    this.photosApi,
    this.commentsApi,
    this.perspectivesApi,
    this.pickImageBytes,
    this.currentUserId,
    this.hasMapboxToken,
    this.mapBuilder,
  });

  final String storyId;
  final StoriesGateway? storiesApi;
  final PeopleGateway? peopleApi;
  final PlacesGateway? placesApi;
  final PhotosGateway? photosApi;
  final CommentsGateway? commentsApi;
  final PerspectivesGateway? perspectivesApi;

  /// Gallery picker override so widget tests never open the system picker.
  final Future<Uint8List?> Function()? pickImageBytes;

  /// Session uid for author-only comment delete. Tests inject this.
  final String? currentUserId;

  /// Defaults to [Env.hasMapboxToken].
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  StoriesGateway? _storiesOverride;
  PeopleGateway? _peopleOverride;
  PlacesGateway? _placesOverride;
  PhotosGateway? _photosOverride;
  CommentsGateway? _commentsOverride;
  PerspectivesGateway? _perspectivesOverride;
  GoRouter? _router;

  var _loading = true;
  var _notFound = false;
  var _mapFailed = false;
  Story? _story;
  List<Person> _peopleOnStory = const [];
  Place? _place;
  List<Photo> _photos = const [];
  Map<String, Uint8List> _previews = const {};
  List<Comment> _comments = const [];
  List<Perspective> _perspectives = const [];
  var _busy = false;
  var _photoError = false;
  var _composingComment = false;
  Uint8List? _pendingPhotoBytes;
  final _composerFocus = FocusNode();
  final _composerKey = GlobalKey();

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  String? get _currentUserId {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PeopleGateway get _people =>
      widget.peopleApi ?? (_peopleOverride ??= PeopleApi());

  PlacesGateway get _places =>
      widget.placesApi ?? (_placesOverride ??= PlacesApi());

  PhotosGateway get _photosApi =>
      widget.photosApi ?? (_photosOverride ??= PhotosApi());

  CommentsGateway get _commentsApi =>
      widget.commentsApi ?? (_commentsOverride ??= CommentsApi());

  PerspectivesGateway get _perspectivesApi =>
      widget.perspectivesApi ?? (_perspectivesOverride ??= PerspectivesApi());

  @override
  void initState() {
    super.initState();
    _mapFailed = !_tokenOk;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _router?.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _composerFocus.dispose();
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    if (path != AppRoutes.storyPath(widget.storyId)) return;
    _reloadPerspectives();
  }

  Future<void> _openPerspective() async {
    final created = await AddPerspectivePage.show(
      context,
      storyId: widget.storyId,
      familyId: _story?.familyId,
      perspectivesApi: _perspectivesApi,
      storiesApi: _stories,
    );
    if (!mounted) return;
    if (created != null && !_perspectives.any((p) => p.id == created.id)) {
      setState(() => _perspectives = [..._perspectives, created]);
    }
    await _reloadPerspectives();
  }

  Future<void> _reloadPerspectives() async {
    try {
      final rows = await _perspectivesApi.listForStory(widget.storyId);
      if (!mounted) return;
      setState(() => _perspectives = rows);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    }
  }

  Future<void> _load() async {
    var loadError = false;
    try {
      final story = await _stories.getPublished(widget.storyId);
      if (!mounted) return;
      if (story == null || story.status != StoryStatus.published) {
        setState(() {
          _loading = false;
          _notFound = true;
          _story = null;
        });
        return;
      }

      List<Person> people = const [];
      try {
        final all = await _people.listPeople(story.familyId);
        people = all.where((p) => story.personIds.contains(p.id)).toList();
      } catch (_) {
        loadError = true;
      }

      Place? place;
      final placeId = story.placeId;
      if (placeId != null && placeId.isNotEmpty) {
        try {
          place = await _places.getPlace(placeId);
        } catch (_) {
          loadError = true;
        }
      }

      List<Photo> photos = const [];
      final previews = <String, Uint8List>{};
      try {
        photos = await _photosApi.listPhotos(story.id);
        for (final photo in photos) {
          try {
            previews[photo.id] = await _photosApi.downloadBytes(
              photo.storagePath,
            );
          } catch (_) {
            // Missing bytes fall back to PhotoStrip placeholder icon.
          }
        }
      } catch (_) {
        loadError = true;
      }

      List<Comment> comments = const [];
      try {
        comments = await _commentsApi.listForStory(story.id);
      } catch (_) {
        loadError = true;
      }

      List<Perspective> perspectives = const [];
      try {
        perspectives = await _perspectivesApi.listForStory(story.id);
      } catch (_) {
        loadError = true;
      }

      if (!mounted) return;
      setState(() {
        _story = story;
        _peopleOnStory = people;
        _place = place;
        _photos = photos;
        _previews = previews;
        _comments = comments;
        _perspectives = perspectives;
        _loading = false;
        _notFound = false;
      });
      if (loadError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Try again')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = false;
        _story = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    }
  }

  void _retryMap() {
    setState(() => _mapFailed = !_tokenOk);
  }

  void _openComposer() {
    setState(() => _composingComment = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocus.requestFocus();
      final ctx = _composerKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          alignment: 1,
        );
      }
    });
  }

  Future<void> _postComment(String body) async {
    final story = _story;
    if (story == null) return;
    try {
      final created = await _commentsApi.create(
        storyId: story.id,
        familyId: story.familyId,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, created];
        _composingComment = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
      rethrow;
    }
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
    if (_busy) return;
    if (_photos.length >= maxPhotosPerStory) return;
    final story = _story;
    if (story == null) return;
    setState(() => _busy = true);
    try {
      final picker = widget.pickImageBytes ?? _pickFromGallery;
      final bytes = await picker();
      if (!mounted || bytes == null) return;
      _pendingPhotoBytes = bytes;
      await _uploadPending();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRetryPhoto() async {
    if (_busy || _pendingPhotoBytes == null) return;
    setState(() => _busy = true);
    try {
      await _uploadPending();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadPending() async {
    final bytes = _pendingPhotoBytes;
    final story = _story;
    if (bytes == null || story == null) return;
    try {
      final photo = await _photosApi.uploadPhoto(
        familyId: story.familyId,
        storyId: story.id,
        bytes: bytes,
        sortOrder: _photos.length,
      );
      if (!mounted) return;
      setState(() {
        _photos = [..._photos, photo];
        _previews = {..._previews, photo.id: bytes};
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
      await _photosApi.deletePhoto(photo);
      if (!mounted) return;
      setState(() {
        _photos = _photos.where((p) => p.id != photo.id).toList();
        _previews = Map.of(_previews)..remove(photo.id);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteComment(Comment row) async {
    try {
      await _commentsApi.delete(row.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != row.id).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('story-reader'),
      appBar: AlbumTopBar(
        leading: TextButton(
          onPressed: () => context.go(AppRoutes.timeline),
          child: const Text('Timeline'),
        ),
      ),
      body: SafeArea(child: AlbumColumn(child: _body(context))),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound) {
      return const Center(child: Text('Not found'));
    }
    if (_story == null) {
      return const SizedBox.shrink();
    }

    final story = _story!;
    final theme = Theme.of(context);
    final place = _place;

    final article = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 17,
      height: 1.45,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                storyHeadline(story.body),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(_timeframeLabel(story), style: theme.textTheme.labelLarge),
              if (_peopleOnStory.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final person in _peopleOnStory)
                      Text(person.name, style: theme.textTheme.labelLarge),
                  ],
                ),
              ],
              if (place != null) ...[
                const SizedBox(height: 4),
                Text(place.label, style: theme.textTheme.labelLarge),
                const SizedBox(height: 12),
                _buildPlaceMap(place),
              ],
              if (storyBodyRest(story.body).isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(storyBodyRest(story.body), style: article),
              ],
              _readingSection(
                title: 'Photos',
                trailing: TextButton(
                  onPressed: _photos.length < maxPhotosPerStory
                      ? _onAddPhoto
                      : null,
                  child: const Text('Add photos'),
                ),
                child: PhotoStrip(
                  photos: _photos,
                  previews: _previews,
                  onAdd: _onAddPhoto,
                  onRemove: _onRemovePhoto,
                  onRetry: _onRetryPhoto,
                  uploadFailed: _photoError,
                  canAdd: _photos.length < maxPhotosPerStory,
                ),
              ),
              _readingSection(
                title: 'Perspectives',
                trailing: TextButton(
                  onPressed: _openPerspective,
                  child: const Text('+ Add your perspective'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in _perspectives) ...[
                      Text(row.authorLabel, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(row.body, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              _readingSection(
                title: 'Comments',
                trailing: TextButton(
                  onPressed: _openComposer,
                  child: const Text('+ Add comment'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in _comments)
                      CommentTile(
                        comment: row,
                        canDelete:
                            _currentUserId != null &&
                            row.authorId == _currentUserId,
                        onDelete: () => _deleteComment(row),
                      ),
                    if (_composingComment)
                      KeyedSubtree(
                        key: _composerKey,
                        child: CommentComposer(
                          onPost: _postComment,
                          focusNode: _composerFocus,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readingSection({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildPlaceMap(Place place) {
    if (_mapFailed || !_tokenOk) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(placeMapFailureCopy),
          TextButton(
            onPressed: _retryMap,
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
        setState(() => _mapFailed = true);
      },
    );
  }
}

String _timeframeLabel(Story story) {
  final end = story.timeframeEnd;
  if (end != null) {
    for (final decade in decadeChips) {
      if (_sameDay(story.timeframeStart, decade.start) &&
          _sameDay(end, decade.end)) {
        return decade.label;
      }
    }
  }
  return _ymd(story.timeframeStart);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _ymd(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

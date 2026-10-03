import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_theme.dart';
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

/// First non-empty line of [body], else `Untitled`.
/// Fallback when a story has no saved title.
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

/// Large reader headline. A saved title wins. Otherwise the first body line.
String readerHeadline({String? title, String? body}) {
  final saved = title?.trim() ?? '';
  if (saved.isNotEmpty) return saved;
  return storyHeadline(body);
}

/// Article under the headline. A saved title keeps the full body.
/// With no title, the lead line is the headline and is left out of the body.
String readerArticleBody({String? title, String? body}) {
  final saved = title?.trim() ?? '';
  if (saved.isNotEmpty) return (body ?? '').trim();
  return storyBodyRest(body);
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
      storyAuthorId: _story?.authorId,
      currentUserId: _currentUserId,
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
        leading: TextButton.icon(
          onPressed: () => context.go(AppRoutes.timeline),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Timeline'),
        ),
      ),
      body: SafeArea(child: AlbumColumn(maxWidth: 1080, child: _body(context))),
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
      fontSize: 18,
      height: 1.55,
    );
    final headline = theme.textTheme.headlineMedium?.copyWith(
      fontSize: 36,
      height: 1.15,
      fontWeight: FontWeight.w700,
    );
    final rest = readerArticleBody(title: story.title, body: story.body);
    final canAddPhoto = _photos.length < maxPhotosPerStory;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7DECE)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                readerHeadline(title: story.title, body: story.body),
                style: headline,
              ),
              if (story.publishedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Documented ${_albumMonthYear(story.publishedAt!)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6B5E55),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE7DECE)),
              const SizedBox(height: 16),
              _metaRow(story, place),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _dropCapText(rest, article),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const Divider(height: 1, color: Color(0xFFE7DECE)),
              const SizedBox(height: 20),
              _sectionHeader(
                icon: Icons.photo_library_outlined,
                iconColor: albumTerracotta,
                title: 'Keepsake Photos & Artifacts',
                subtitle: _photoCountLine(_photos.length),
                trailing: TextButton.icon(
                  onPressed: canAddPhoto ? _onAddPhoto : null,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('Add photos'),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 900 ? 4 : (width >= 560 ? 2 : 1);
                  return PhotoStrip(
                    photos: _photos,
                    previews: _previews,
                    onAdd: _onAddPhoto,
                    onRemove: _onRemovePhoto,
                    onRetry: _onRetryPhoto,
                    uploadFailed: _photoError,
                    canAdd: canAddPhoto,
                    columns: columns,
                    addLabel: 'Add photos to story',
                    addHint: 'Up to $maxPhotosPerStory photos',
                  );
                },
              ),
              const SizedBox(height: 28),
              const Divider(height: 1, color: Color(0xFFE7DECE)),
              const SizedBox(height: 20),
              _sectionHeader(
                icon: Icons.diversity_3_outlined,
                iconColor: albumSage,
                title: 'Perspectives',
                subtitle:
                    'Full alternate tellings contributed by family members',
                trailing: FilledButton.icon(
                  onPressed: _openPerspective,
                  style: FilledButton.styleFrom(
                    backgroundColor: albumTerracotta,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('+ Add your perspective'),
                ),
              ),
              if (_perspectives.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final row in _perspectives) ...[
                  _perspectiveCard(row),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE7DECE)),
              const SizedBox(height: 20),
              _sectionHeader(
                icon: Icons.forum_outlined,
                iconColor: albumTerracotta,
                title: 'Comments',
                countLabel: _comments.length == 1
                    ? '1 note'
                    : '${_comments.length} notes',
                trailing: TextButton.icon(
                  onPressed: _openComposer,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('+ Add comment'),
                ),
              ),
              const SizedBox(height: 12),
              for (final row in _comments)
                CommentTile(
                  comment: row,
                  canDelete:
                      _currentUserId != null && row.authorId == _currentUserId,
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
      ),
    );
  }

  Widget _metaRow(Story story, Place? place) {
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _timeframePill(_timeframeLabel(story)),
        for (final person in _peopleOnStory) _personChip(person),
      ],
    );
    if (place == null) return chips;
    return LayoutBuilder(
      builder: (context, constraints) {
        final location = _locationCard(place);
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [chips, const SizedBox(height: 12), location],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: chips),
            const SizedBox(width: 16),
            SizedBox(width: 280, child: location),
          ],
        );
      },
    );
  }

  Widget _timeframePill(String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: albumTerracotta),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personChip(Person person) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _initialsAvatar(person.name, size: 22),
            const SizedBox(width: 6),
            Text(person.name, style: Theme.of(context).textTheme.labelMedium),
            if (person.relationship.trim().isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                person.relationship,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFF6B5E55)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationCard(Place place) {
    final failed = _mapFailed || !_tokenOk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!failed)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 96, child: _buildPlaceMap(place)),
              ),
            if (!failed) const SizedBox(width: 10),
            Expanded(child: _locationCopy(place, failed: failed)),
          ],
        ),
      ),
    );
  }

  Widget _locationCopy(Place place, {required bool failed}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pin_drop_outlined, size: 14, color: albumSage),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Story Location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: albumSage, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          place.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          place.address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: const Color(0xFF6B5E55)),
        ),
        if (failed) ...[
          const SizedBox(height: 8),
          const Text(placeMapFailureCopy),
          TextButton(
            onPressed: _retryMap,
            child: const Text(placeMapRetryLabel),
          ),
        ],
      ],
    );
  }

  Widget _perspectiveCard(Perspective row) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DECE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _initialsAvatar(row.authorLabel, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.authorLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Recorded ${_albumDate(row.createdAt)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF6B5E55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: albumTerracotta, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  row.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? countLabel,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (countLabel != null) ...[
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EDE6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    countLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF6B5E55),
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 8), trailing],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            trailing,
          ],
        );
      },
    );
  }

  Widget _initialsAvatar(String name, {required double size}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFE7D5CC),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            _initials(name),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: size < 28 ? 9 : 12,
              fontWeight: FontWeight.w700,
              color: albumTerracotta,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropCapText(String text, TextStyle? article) {
    final style = article ?? const TextStyle(fontSize: 18, height: 1.5);
    final chars = text.characters;
    final first = chars.first;
    final rest = chars.skip(1).string;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: first,
            style: style.copyWith(fontSize: 52, height: 0.8),
          ),
          TextSpan(text: rest),
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
      height: 72,
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

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _albumDate(DateTime value) {
  final local = value.toLocal();
  return '${_monthShort[local.month - 1]} ${local.day}, ${local.year}';
}

String _albumMonthYear(DateTime value) {
  final local = value.toLocal();
  return '${_monthShort[local.month - 1]} ${local.year}';
}

String _photoCountLine(int count) {
  final noun = count == 1 ? 'family item' : 'family items';
  return '$count $noun attached to this memory';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

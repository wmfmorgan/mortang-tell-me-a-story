import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/display_name.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/comment.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/perspective.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/photo.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/timeline_live.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_modal_frame.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/core/widgets/story/photo_frame.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/comments/presentation/comment_composer.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/people/presentation/person_profile_dialog.dart';
import 'package:tell_me_a_story/features/perspectives/presentation/add_perspective_page.dart';
import 'package:tell_me_a_story/features/stories/presentation/photo_strip.dart';
import 'package:tell_me_a_story/features/stories/presentation/reader_meta.dart';
import 'package:tell_me_a_story/features/stories/presentation/story_reader_providers.dart';

part 'story_reader_body.dart';
part 'story_reader_widgets.dart';

/// Large reader headline. Only a saved title is used.
String readerHeadline({String? title}) {
  final saved = title?.trim() ?? '';
  if (saved.isNotEmpty) return saved;
  return '';
}

/// Article under the headline. The full body stays, including its first line.
String readerArticleBody({String? body}) {
  return (body ?? '').trim();
}

class OriginMenuEntry {
  const OriginMenuEntry({required this.familyId, required this.label});

  final String familyId;
  final String label;
}

/// Published stories only. The label is always `Set as origin for {Family}`.
List<OriginMenuEntry> originMenuEntries({
  required bool published,
  required String storyFamilyId,
  required List<TreeFamily> tree,
  required Map<String, String> stewardRoles,
}) {
  if (!published) return const [];
  final storyFamily = _familyIn(tree, storyFamilyId);
  final entries = <OriginMenuEntry>[];
  if (storyFamily != null &&
      storyFamily.parentFamilyId == null &&
      originSteward(stewardRoles[storyFamilyId])) {
    entries.add(
      OriginMenuEntry(
        familyId: storyFamilyId,
        label: 'Set as origin for ${storyFamily.name}',
      ),
    );
  }
  final children = [
    for (final row in tree)
      if (row.parentFamilyId == storyFamilyId &&
          originSteward(stewardRoles[row.id]))
        row,
  ]..sort((a, b) => a.name.compareTo(b.name));
  for (final child in children) {
    entries.add(
      OriginMenuEntry(
        familyId: child.id,
        label: 'Set as origin for ${child.name}',
      ),
    );
  }
  return entries;
}

String originDeleteBody(List<String> names) {
  if (names.length == 1) {
    return 'This story starts the ${names.single} timeline. Delete anyway?';
  }
  if (names.length == 2) {
    return 'This story starts the ${names[0]} and ${names[1]} timelines. Delete anyway?';
  }
  final head = names.sublist(0, names.length - 1).join(', ');
  return 'This story starts the $head, and ${names.last} timelines. Delete anyway?';
}

TreeFamily? _familyIn(List<TreeFamily> tree, String familyId) {
  for (final row in tree) {
    if (row.id == familyId) return row;
  }
  return null;
}

/// [familyId]'s non-blank name in [tree], or null.
String? _namedFamily(String familyId, List<TreeFamily> tree) {
  for (final row in tree) {
    if (row.id == familyId && row.name.trim().isNotEmpty) return row.name;
  }
  return null;
}

/// The loaded story data, or null while loading, failed or missing.
ReaderData? _readyData(AsyncValue<ReaderLoad> load) {
  if (load.hasError) return null;
  return switch (load.value) {
    ReaderReady(:final data) => data,
    _ => null,
  };
}

/// Author always; a live owner/co-owner of the story family once published.
bool _canEditStory(ReaderData? data, String? uid) {
  if (data == null || uid == null) return false;
  final story = data.story;
  if (uid == story.authorId) return true;
  if (story.status != StoryStatus.published) return false;
  return data.stewarded.any(
    (row) =>
        row.id == story.familyId &&
        row.deletedAt == null &&
        (row.role == 'owner' || row.role == 'co_owner'),
  );
}

List<OriginMenuEntry> _originEntries(ReaderData? data) {
  if (data == null) return const [];
  return originMenuEntries(
    published: data.story.status == StoryStatus.published,
    storyFamilyId: data.story.familyId,
    tree: data.tree,
    stewardRoles: {
      for (final row in data.stewarded)
        if (row.deletedAt == null) row.id: row.role,
    },
  );
}

/// Published-only reader at `/stories/:storyId`.
class StoryReaderPage extends ConsumerStatefulWidget {
  const StoryReaderPage({
    super.key,
    required this.storyId,
    this.pickImageBytes,
    this.currentUserId,
  });

  final String storyId;

  /// Gallery picker override so widget tests never open the system picker.
  final Future<Uint8List?> Function()? pickImageBytes;

  /// Session uid for author-only comment delete. Tests inject this.
  final String? currentUserId;

  @override
  ConsumerState<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends ConsumerState<StoryReaderPage> {
  GoRouter? _router;
  String? _watchedStory;
  var _busy = false;
  var _editOpen = false;
  var _confirming = false;
  var _photoError = false;
  var _heroIndex = 0;
  var _composingComment = false;
  String? _editingCommentId;
  Uint8List? _pendingPhotoBytes;
  final _composerFocus = FocusNode();
  final _editFocus = FocusNode();
  final _composerKey = GlobalKey();

  StoryReaderProvider get _provider => storyReaderProvider(widget.storyId);

  StoryReader get _reader => ref.read(_provider.notifier);

  ReaderData? get _data => _readyData(ref.read(_provider));

  String? get _currentUserId =>
      widget.currentUserId ?? ref.read(appSessionProvider).currentUserId;

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
    _editFocus.dispose();
    super.dispose();
  }

  /// A server load landed: follow the story live, reset the carousel, and
  /// report failed loads.
  void _onLoad(AsyncValue<ReaderLoad>? previous, AsyncValue<ReaderLoad> next) {
    if (next.hasError) {
      _showTryAgain();
      return;
    }
    final data = _readyData(next);
    if (data == null) return;
    final before = previous == null ? null : _readyData(previous);
    if (before?.generation == data.generation) return;
    _watchStory(data.story.id);
    setState(() => _heroIndex = 0);
    if (data.partialError) _showTryAgain();
  }

  void _showTryAgain() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Try again')));
  }

  void _watchStory(String storyId) {
    if (_watchedStory == storyId) return;
    _watchedStory = storyId;
    ref
        .read(timelineLiveProvider)
        .watchStory(
          storyId: storyId,
          onChange: () {
            if (!mounted || _busy || _composingComment) return;
            _reader.reload();
          },
        );
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    if (path != AppRoutes.storyPath(widget.storyId)) return;
    _reloadPerspectives();
  }

  Future<void> _openEdit() async {
    final id = _data?.story.id;
    if (id == null || GoRouter.maybeOf(context) == null) return;
    setState(() => _editOpen = true);
    try {
      final saved = await context.push<bool>(AppRoutes.storyEditPath(id));
      if (!mounted || saved != true) return;
      await _reader.reload();
    } finally {
      if (mounted) setState(() => _editOpen = false);
    }
  }

  Future<void> _openPerspective() async {
    final story = _data?.story;
    final created = await AddPerspectivePage.show(
      context,
      storyId: widget.storyId,
      familyId: story?.familyId,
      storyAuthorId: story?.authorId,
      currentUserId: _currentUserId,
    );
    if (!mounted) return;
    if (created != null) {
      _reader.edit((data) {
        if (data.perspectives.any((p) => p.id == created.id)) return data;
        return data.copyWith(perspectives: [...data.perspectives, created]);
      });
    }
    await _reloadPerspectives();
  }

  /// The caller wrote this note and can still contribute: they may edit it.
  bool _ownsNote(ReaderData data, String? authorId) {
    final uid = _currentUserId;
    return data.canWrite && uid != null && authorId == uid;
  }

  Future<void> _openEditPerspective(Perspective row) async {
    final story = _data?.story;
    final updated = await AddPerspectivePage.show(
      context,
      storyId: widget.storyId,
      familyId: story?.familyId ?? row.familyId,
      storyAuthorId: story?.authorId,
      currentUserId: _currentUserId,
      existing: row,
    );
    if (!mounted || updated == null) return;
    _reader.edit(
      (data) => data.copyWith(
        perspectives: [
          for (final item in data.perspectives)
            if (item.id == updated.id) updated else item,
        ],
      ),
    );
    await _reloadPerspectives();
  }

  Future<void> _confirmDeletePerspective(Perspective row) async {
    if (_confirming) return;
    _confirming = true;
    try {
      final confirmed = await showFamilyBlurDialog(
        context,
        dialogKey: const Key('delete-perspective-dialog'),
        title: 'Delete this perspective?',
        confirmLabel: 'Delete perspective',
        confirmKey: const Key('delete-perspective-go'),
        confirmColor: albumTerracotta,
      );
      if (!confirmed || !mounted) return;
      await ref.read(perspectivesRepositoryProvider).delete(row.id);
      if (!mounted) return;
      _reader.edit(
        (data) => data.copyWith(
          perspectives: [
            for (final item in data.perspectives)
              if (item.id != row.id) item,
          ],
        ),
      );
      await _reloadPerspectives();
    } catch (_) {
      // Any failure keeps the card and shows the reader's retry copy.
      _showTryAgain();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _reloadPerspectives() async {
    try {
      final rows = await ref
          .read(perspectivesRepositoryProvider)
          .listForStory(widget.storyId);
      if (!mounted) return;
      _reader.edit((data) => data.copyWith(perspectives: rows));
    } catch (_) {
      // Keeps the listed perspectives and shows the reader's retry copy.
      _showTryAgain();
    }
  }

  void _onOverflow(String value) {
    final story = _data?.story;
    if (story == null) return;
    if (value == 'start-timeline') {
      _startNewTimeline(story);
      return;
    }
    if (value == 'delete') {
      _confirmDelete(story);
      return;
    }
    for (final entry in _originEntries(_data)) {
      if (entry.familyId == value) {
        _confirmOrigin(story, entry);
        return;
      }
    }
  }

  Future<void> _startNewTimeline(Story story) async {
    final userId = _currentUserId;
    if (userId == null) return;
    final parentName = await _parentName(story.familyId);
    if (parentName == null || !mounted) return;
    final created = await showStartTimelineDialog(
      context,
      parentId: story.familyId,
      parentName: parentName,
      stories: const [],
      currentUserId: userId,
      origin: story,
      allowChange: false,
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  /// The loaded tree first, then the caller's families, then a fresh tree.
  Future<String?> _parentName(String familyId) async {
    final loaded = _namedFamily(familyId, _data?.tree ?? const []);
    if (loaded != null) return loaded;
    final families = ref.read(familiesRepositoryProvider);
    try {
      final mine = await families.listMine();
      for (final row in mine) {
        if (row.id == familyId && row.name.trim().isNotEmpty) return row.name;
      }
    } on AppException {
      // Fall through to the tree lookup.
    }
    try {
      return _namedFamily(familyId, await families.listFamilyTree(familyId));
    } on AppException {
      return null;
    }
  }

  Future<void> _confirmOrigin(Story story, OriginMenuEntry entry) async {
    final family = _familyIn(_data?.tree ?? const [], entry.familyId);
    final name = family?.name ?? 'Family';
    final confirmed = await showFamilyBlurDialog(
      context,
      dialogKey: const Key('set-origin-confirm'),
      title: 'Set as the origin of $name?',
      body: 'This story will appear first on the $name timeline.',
      confirmLabel: 'Set origin',
      confirmKey: const Key('set-origin-go'),
      confirmColor: albumTerracotta,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(familiesRepositoryProvider)
          .setFamilyOrigin(familyId: entry.familyId, storyId: story.id);
      if (!mounted) return;
      _leave();
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      // Unknown failures show the generic retry copy.
      _showTryAgain();
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.timeline);
    }
  }

  Future<void> _confirmDelete(Story story) async {
    if (_confirming) return;
    _confirming = true;
    try {
      final dependents = await ref
          .read(familiesRepositoryProvider)
          .listOriginDependents(story.id);
      if (!mounted) return;
      final names = [for (final row in dependents) row.name];
      final warning = names.isNotEmpty;
      final confirmed = await showFamilyBlurDialog(
        context,
        dialogKey: Key(
          warning ? 'delete-origin-warning' : 'delete-story-dialog',
        ),
        title: 'Delete this story?',
        body: warning ? originDeleteBody(names) : null,
        confirmLabel: 'Delete story',
        confirmKey: const Key('delete-story-go'),
        confirmColor: albumTerracotta,
      );
      if (!confirmed || !mounted) return;
      await ref.read(storiesRepositoryProvider).discard(story.id);
      if (!mounted) return;
      _leave();
    } catch (_) {
      // The story stays; show the reader's retry copy.
      _showTryAgain();
    } finally {
      _confirming = false;
    }
  }

  void _openComposer() {
    setState(() {
      _composingComment = true;
      _editingCommentId = null;
    });
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
    final story = _data?.story;
    if (story == null) return;
    try {
      final created = await ref
          .read(commentsRepositoryProvider)
          .create(storyId: story.id, familyId: story.familyId, body: body);
      if (!mounted) return;
      _reader.edit(
        (data) => data.copyWith(comments: [...data.comments, created]),
      );
      setState(() => _composingComment = false);
    } catch (_) {
      // The composer keeps its text: report and rethrow.
      _showTryAgain();
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
    final data = _data;
    if (data == null || data.photos.length >= maxPhotosPerStory) return;
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
    final data = _data;
    if (bytes == null || data == null) return;
    try {
      final photo = await ref
          .read(photosRepositoryProvider)
          .uploadPhoto(
            familyId: data.story.familyId,
            storyId: data.story.id,
            bytes: bytes,
            sortOrder: data.photos.length,
          );
      if (!mounted) return;
      _reader.edit(
        (data) => data.copyWith(
          photos: [...data.photos, photo],
          previews: {...data.previews, photo.id: bytes},
        ),
      );
      setState(() {
        _photoError = false;
        _pendingPhotoBytes = null;
      });
    } catch (_) {
      // Shown as the strip's upload failure copy with Try again.
      if (!mounted) return;
      setState(() => _photoError = true);
    }
  }

  Future<void> _onRemovePhoto(Photo photo) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(photosRepositoryProvider).deletePhoto(photo);
      if (!mounted) return;
      _reader.edit(
        (data) => data.copyWith(
          photos: [
            for (final p in data.photos)
              if (p.id != photo.id) p,
          ],
          previews: Map.of(data.previews)..remove(photo.id),
        ),
      );
    } catch (_) {
      // The photo stays; show the reader's retry copy.
      _showTryAgain();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEditComment(Comment row) {
    setState(() {
      _editingCommentId = row.id;
      _composingComment = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editFocus.requestFocus();
    });
  }

  void _cancelEditComment() => setState(() => _editingCommentId = null);

  Future<void> _saveComment(Comment row, String body) async {
    try {
      await ref.read(commentsRepositoryProvider).update(id: row.id, body: body);
      if (!mounted) return;
      _reader.edit(
        (data) => data.copyWith(
          comments: [
            for (final item in data.comments)
              if (item.id == row.id) item.copyWith(body: body.trim()) else item,
          ],
        ),
      );
      setState(() => _editingCommentId = null);
    } catch (_) {
      // The edit field keeps its text: report and rethrow.
      _showTryAgain();
      rethrow;
    }
  }

  Future<void> _deleteComment(Comment row) async {
    try {
      await ref.read(commentsRepositoryProvider).delete(row.id);
      if (!mounted) return;
      _reader.edit(
        (data) => data.copyWith(
          comments: [
            for (final c in data.comments)
              if (c.id != row.id) c,
          ],
        ),
      );
      if (_editingCommentId == row.id) {
        setState(() => _editingCommentId = null);
      }
    } catch (_) {
      // The comment stays; show the reader's retry copy.
      _showTryAgain();
    }
  }

  void _stepHero(int delta, int count) {
    if (count < 2) return;
    setState(() {
      _heroIndex = (_heroIndex + delta) % count;
      if (_heroIndex < 0) _heroIndex += count;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the live feed open while the reader is shown.
    ref.watch(timelineLiveProvider);
    ref.listen(_provider, _onLoad);
    final load = ref.watch(_provider);
    final data = _readyData(load);
    final uid = _currentUserId;
    // The edit page paints its own scrim. Menus stay on this one.
    return AlbumModalFrame(
      frameKey: const Key('story-reader-modal'),
      markKey: const Key('story-reader-mark'),
      label: 'STORY',
      showScrim: !_editOpen,
      trailing: _ReaderTrailing(
        canEdit: _canEditStory(data, uid),
        onEdit: _busy ? null : _openEdit,
        overflow: _ReaderOverflow(
          entries: _originEntries(data),
          canDelete: data != null && uid != null && uid == data.story.authorId,
          showStartTimeline:
              data != null &&
              data.story.status == StoryStatus.published &&
              data.memberOfStoryFamily,
          onSelected: _onOverflow,
        ),
      ),
      child: switch (load) {
        AsyncError() => const SizedBox.shrink(),
        AsyncData(value: ReaderMissing()) => const Center(
          child: Text('Not found'),
        ),
        AsyncData(value: ReaderReady(:final data)) => _ReaderBody(
          host: this,
          data: data,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

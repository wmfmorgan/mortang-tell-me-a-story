import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/cover_photo_exception.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/family/presentation/family_providers.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_host.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal.dart';

/// Default home for a live family. Hero, then the Latest shelf.
class FamilyLandingPage extends ConsumerStatefulWidget {
  const FamilyLandingPage({super.key, this.pickImage, this.now = utcNow});

  final Future<Uint8List?> Function()? pickImage;

  /// Clock for the Latest window. Must be stable across rebuilds.
  final DateTime Function() now;

  @override
  ConsumerState<FamilyLandingPage> createState() => _FamilyLandingPageState();
}

class _FamilyLandingPageState extends ConsumerState<FamilyLandingPage> {
  FamilyLandingProvider get _provider =>
      familyLandingProvider(clock: widget.now);

  /// Last loaded data; kept while a reload shows the blank body.
  FamilyLandingData? get _data => ref.read(_provider).value;

  Future<void> _reload() async {
    ref.invalidate(_provider);
    await ref.read(_provider.future);
  }

  Future<void> _selectFamily(String id) async {
    ref.read(familySelectionProvider.notifier).remember(id);
    if (id == _data?.familyId) return;
    await _reload();
  }

  Future<void> _openInvite() async {
    final data = _data;
    final family = data?.family;
    final id = family?.id ?? data?.familyId;
    if (id == null || !mounted) return;
    await InviteModal.show(
      context,
      familyId: id,
      familyName: family?.name ?? 'Family',
    );
  }

  Future<void> _startTimeline() async {
    final family = _data?.family;
    if (family == null || !mounted) return;
    final userId = ref.read(appSessionProvider).currentUserId;
    if (userId == null) return;
    List<Story> stories = const [];
    try {
      stories = await ref
          .read(storiesRepositoryProvider)
          .listPublished(family.id);
    } catch (error) {
      // Mapped to copy and shown in a snack.
      if (!mounted) return;
      _snack(appErrorMessage(error) ?? 'Try again');
      return;
    }
    if (!mounted) return;
    final created = await openStartTimeline(
      context,
      parentId: family.id,
      parentName: family.name,
      stories: stories,
      userId: userId,
    );
    if (created == null || !mounted) return;
    _snack('${created.name} timeline created');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editCover() async {
    final family = _data?.family;
    if (family == null || !originSteward(family.role)) return;
    final bytes = await _pickBytes();
    if (bytes == null || !mounted) return;
    final choice = await showDialog<_CoverChoice>(
      context: context,
      builder: (context) => _CoverPreviewDialog(
        bytes: bytes,
        canRemove: family.coverPhotoPath != null,
      ),
    );
    if (!mounted || choice == null) return;
    try {
      await _applyCover(family, choice);
      if (!mounted) return;
      await _reload();
    } catch (error) {
      // Mapped to copy and shown in a snack.
      if (!mounted) return;
      _snack(
        error is CoverPhotoException
            ? error.message
            : appErrorMessage(error) ??
                  'Couldn’t save the family photo. Try again.',
      );
    }
  }

  Future<void> _applyCover(MemberFamily family, _CoverChoice choice) async {
    final api = ref.read(familiesRepositoryProvider);
    switch (choice.bytes) {
      case final bytes?:
        await api.setCoverPhoto(
          familyId: family.id,
          bytes: bytes,
          previousPath: family.coverPhotoPath,
        );
      case null:
        await api.clearCoverPhoto(
          familyId: family.id,
          path: family.coverPhotoPath,
        );
    }
  }

  Future<Uint8List?> _pickBytes() async {
    final pick = widget.pickImage;
    if (pick != null) return pick();
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _openStory(Story story) async {
    if (GoRouter.maybeOf(context) == null) return;
    await context.push(AppRoutes.storyPath(story.id));
  }

  @override
  Widget build(BuildContext context) {
    final landing = ref.watch(_provider);
    final data = landing.value;
    final memberIds = data?.memberIds ?? const <String>{};
    final familyId = data?.familyId;
    final canWrite = familyId != null && memberIds.contains(familyId);
    return Scaffold(
      key: const Key('family-landing'),
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.familyLanding,
        familyName: data?.family?.name ?? 'Family',
        families: data?.families ?? const <MemberFamily>[],
        currentFamilyId: familyId,
        onFamilySelected: (id) {
          _selectFamily(id);
        },
        stewarded: data?.stewarded ?? const <StewardFamily>[],
        relatedFamilies: [
          for (final TreeFamily row in data?.tree ?? const [])
            if (!memberIds.contains(row.id)) row,
        ],
        canWrite: canWrite,
        onInvite: canWrite ? _openInvite : null,
        onStartTimeline: canWrite ? _startTimeline : null,
      ),
      body: landing.when(
        skipLoadingOnRefresh: false,
        loading: () => const SizedBox.shrink(),
        error: (error, _) =>
            Center(child: Text(appErrorMessage(error) ?? 'Try again')),
        data: (data) => _LandingBody(
          data: data,
          onEditCover: _editCover,
          onOpen: _openStory,
        ),
      ),
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody({
    required this.data,
    required this.onEditCover,
    required this.onOpen,
  });

  final FamilyLandingData data;
  final VoidCallback onEditCover;
  final ValueChanged<Story> onOpen;

  @override
  Widget build(BuildContext context) {
    final family = data.family;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: AlbumColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              familyName: family?.name ?? 'Family',
              bytes: data.coverBytes,
              canEdit: originSteward(family?.role),
              onEdit: onEditCover,
            ),
            const SizedBox(height: 28),
            _LatestShelf(
              familyName: family?.name ?? 'Family',
              familyId: data.familyId,
              stories: data.latest,
              thumbs: data.thumbs,
              onOpen: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverChoice {
  const _CoverChoice.save(this.bytes) : remove = false;
  const _CoverChoice.remove() : bytes = null, remove = true;

  final Uint8List? bytes;
  final bool remove;
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.familyName,
    required this.bytes,
    required this.canEdit,
    required this.onEdit,
  });

  final String familyName;
  final Uint8List? bytes;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    return AspectRatio(
      key: const Key('family-landing-hero'),
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: albumInk.withValues(alpha: 0.12)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: albumParchment,
                child: bytes == null
                    ? _HeroPlaceholder(familyName: familyName, canEdit: canEdit)
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
              if (canEdit)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    key: const Key('family-landing-hero-edit'),
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      backgroundColor: albumDialogSurface,
                      foregroundColor: albumInk,
                    ),
                    icon: const Icon(Icons.photo_camera),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({required this.familyName, required this.canEdit});

  final String familyName;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FamilyMonogram(name: familyName, size: 72),
        if (canEdit) ...[
          const SizedBox(height: 12),
          Text(
            'Add a family photo',
            style: GoogleFonts.sourceSans3(
              color: albumInk.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ],
    );
  }
}

class _LatestShelf extends StatelessWidget {
  const _LatestShelf({
    required this.familyName,
    required this.familyId,
    required this.stories,
    required this.thumbs,
    required this.onOpen,
  });

  final String familyName;
  final String? familyId;
  final List<Story> stories;
  final Map<String, Uint8List> thumbs;
  final ValueChanged<Story> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('family-landing-latest'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 32,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Added in the past 7 days.',
          style: GoogleFonts.sourceSans3(
            color: albumInk.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        if (stories.isEmpty)
          Text(
            'No stories added in the past 7 days.',
            style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 16),
          )
        else
          _ShelfList(stories: stories, thumbs: thumbs, onOpen: onOpen),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.thumb,
    required this.onTap,
  });

  final Story story;
  final Uint8List? thumb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = _recordedWhen(story);
    final title = (story.title ?? '').trim();
    return SizedBox(
      width: 200,
      child: Material(
        color: albumParchment,
        child: InkWell(
          key: Key('family-landing-card-${story.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardThumb(thumb: thumb),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.newsreader(
                  color: albumInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (when != null) ...[
                const SizedBox(height: 4),
                Text(
                  when,
                  style: GoogleFonts.sourceSans3(
                    color: albumInk.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfList extends StatelessWidget {
  const _ShelfList({
    required this.stories,
    required this.thumbs,
    required this.onOpen,
  });

  final List<Story> stories;
  final Map<String, Uint8List> thumbs;
  final ValueChanged<Story> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final story = stories[index];
          return _StoryCard(
            story: story,
            thumb: thumbs[story.id],
            onTap: () => onOpen(story),
          );
        },
      ),
    );
  }
}

class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.thumb});

  final Uint8List? thumb;

  @override
  Widget build(BuildContext context) {
    final thumb = this.thumb;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: albumParchment,
          child: thumb == null
              ? const SizedBox.expand()
              : Image.memory(thumb, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

String? _recordedWhen(Story story) {
  final start = story.timeframeStart;
  if (start == null) return null;
  return storyDateLabel(
    StoryDate.fromRow(start, story.timeframeEnd, story.datePrecision),
  );
}

class _CoverPreviewDialog extends StatelessWidget {
  const _CoverPreviewDialog({required this.bytes, required this.canRemove});

  final Uint8List bytes;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: albumDialogSurface,
      content: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      ),
      actions: [
        if (canRemove)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _CoverChoice.remove()),
            child: Text(
              'Remove photo',
              style: GoogleFonts.sourceSans3(color: albumInk),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.sourceSans3(color: albumInk),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_CoverChoice.save(bytes)),
          child: Text(
            'Save',
            style: GoogleFonts.sourceSans3(color: albumTerracotta),
          ),
        ),
      ],
    );
  }
}

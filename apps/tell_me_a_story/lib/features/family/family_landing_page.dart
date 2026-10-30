import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_covers.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/people_api.dart';
import '../../data/photos_api.dart';
import '../../data/rpc_error.dart';
import '../../data/stories_api.dart';
import '../invites/invite_modal.dart';
import '../stories/story_date.dart';
import 'family_role.dart';
import 'start_timeline_host.dart';

/// Default home for a live family. Hero, then the Latest shelf.
class FamilyLandingPage extends StatefulWidget {
  const FamilyLandingPage({
    super.key,
    this.api,
    this.storiesApi,
    this.familiesApi,
    this.photosApi,
    this.peopleApi,
    this.manageApi,
    this.loadLatest,
    this.pickImage,
    this.now,
  });

  final InviteGateway? api;
  final StoriesGateway? storiesApi;
  final FamiliesGateway? familiesApi;
  final PhotosGateway? photosApi;
  final PeopleGateway? peopleApi;
  final ManageFamiliesGateway? manageApi;
  final Future<List<Story>> Function(String familyId)? loadLatest;
  final Future<Uint8List?> Function()? pickImage;
  final DateTime Function()? now;

  @override
  State<FamilyLandingPage> createState() => _FamilyLandingPageState();
}

class _FamilyLandingPageState extends State<FamilyLandingPage> {
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  List<TreeFamily> _tree = const [];
  Set<String> _memberIds = const {};
  String? _familyId;
  List<Story> _latest = const [];
  Map<String, Uint8List> _thumbs = const {};
  Uint8List? _coverBytes;
  var _loading = true;

  DateTime get _now => widget.now?.call() ?? DateTime.now().toUtc();

  MemberFamily? get _family {
    final id = _familyId;
    for (final family in _families) {
      if (family.id == id) return family;
    }
    return null;
  }

  bool get _canEditCover => originSteward(_family?.role);

  bool get _canWrite {
    final id = _familyId;
    return id != null && _memberIds.contains(id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gateway = widget.familiesApi;
    List<MemberFamily> rows = const [];
    List<StewardFamily> stewarded = const [];
    var memberIds = <String>{};
    try {
      if (gateway != null) {
        rows = await gateway.listMine();
        stewarded = await gateway.listStewarded();
      } else {
        final live = FamiliesApi();
        rows = await live.listMine();
        stewarded = await live.listStewarded();
      }
      memberIds = rows.map((row) => row.id).toSet();
    } catch (_) {
      rows = const [];
      stewarded = const [];
      memberIds = {};
    }

    var familyId = FamilySelection.id;
    if (rows.isNotEmpty &&
        (familyId == null || !rows.any((family) => family.id == familyId))) {
      familyId = rows.first.id;
      FamilySelection.remember(familyId);
    }

    List<TreeFamily> tree = const [];
    if (familyId != null) {
      try {
        if (gateway != null) {
          tree = await gateway.listFamilyTree(familyId);
        } else {
          tree = await FamiliesApi().listFamilyTree(familyId);
        }
      } catch (_) {
        tree = const [];
      }
    }

    var latest = const <Story>[];
    if (familyId != null) {
      try {
        latest = latestShelf(await _fetchLatest(familyId), now: _now);
      } catch (_) {
        latest = const [];
      }
    }

    final family = _familyFrom(rows, familyId);
    Uint8List? cover;
    if (family?.coverPhotoPath != null) {
      cover = await _downloadCover(family!.coverPhotoPath);
    }
    final thumbs = await _downloadThumbs(latest);

    if (!mounted) return;
    setState(() {
      _families = rows;
      _stewarded = stewarded;
      _tree = tree;
      _memberIds = memberIds;
      _familyId = familyId;
      _latest = latest;
      _coverBytes = cover;
      _thumbs = thumbs;
      _loading = false;
    });
  }

  MemberFamily? _familyFrom(List<MemberFamily> rows, String? id) {
    for (final family in rows) {
      if (family.id == id) return family;
    }
    return null;
  }

  Future<List<Story>> _fetchLatest(String familyId) {
    final load = widget.loadLatest;
    if (load != null) return load(familyId);
    final api = widget.storiesApi ?? StoriesApi();
    return api.listLatestPublished(familyId, now: _now);
  }

  Future<Uint8List?> _downloadCover(String? path) async {
    final families = widget.familiesApi;
    try {
      if (families is FamilyCoverClient) {
        return await (families as FamilyCoverClient).download(path);
      }
      if (families == null) return await FamilyCoversApi().download(path);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, Uint8List>> _downloadThumbs(List<Story> stories) async {
    final photos = widget.photosApi;
    final out = <String, Uint8List>{};
    for (final story in stories) {
      if (story.photoPaths.isEmpty) continue;
      try {
        final bytes = photos == null
            ? await PhotosApi().downloadBytes(story.photoPaths.first)
            : await photos.downloadBytes(story.photoPaths.first);
        out[story.id] = bytes;
      } catch (_) {
        // A missing thumb stays a parchment blank.
      }
    }
    return out;
  }

  Future<void> _selectFamily(String id) async {
    FamilySelection.remember(id);
    if (id == _familyId) return;
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _openInvite() async {
    final family = _family;
    final id = family?.id ?? _familyId;
    if (id == null || !mounted) return;
    await InviteModal.show(
      context,
      familyId: id,
      familyName: family?.name ?? 'Family',
      api: widget.api,
      people: widget.peopleApi,
    );
  }

  Future<void> _startTimeline() async {
    final family = _family;
    if (family == null || !mounted) return;
    final userId = signedInUserId();
    if (userId == null) return;
    List<Story> stories = const [];
    try {
      final api = widget.storiesApi ?? StoriesApi();
      stories = await api.listPublished(family.id);
    } catch (error) {
      if (!mounted) return;
      _snack(mapRpcError(error) ?? 'Try again');
      return;
    }
    if (!mounted) return;
    final created = await openStartTimeline(
      context,
      parentId: family.id,
      parentName: family.name,
      stories: stories,
      userId: userId,
      familiesApi: widget.familiesApi ?? FamiliesApi(),
      peopleApi: widget.peopleApi ?? PeopleApi(),
      manageApi: widget.manageApi ?? ManageFamiliesApi(),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editCover() async {
    final family = _family;
    if (family == null || !_canEditCover) return;
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
      final api = widget.familiesApi ?? FamiliesApi();
      if (choice.remove) {
        await api.clearCoverPhoto(
          familyId: family.id,
          path: family.coverPhotoPath,
        );
      } else {
        await api.setCoverPhoto(
          familyId: family.id,
          bytes: choice.bytes!,
          previousPath: family.coverPhotoPath,
        );
      }
      if (!mounted) return;
      setState(() => _loading = true);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _snack(
        error is CoverPhotoException
            ? error.message
            : mapRpcError(error) ??
                  'Couldn’t save the family photo. Try again.',
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

  @override
  Widget build(BuildContext context) {
    final family = _family;
    final related = [
      for (final row in _tree)
        if (!_memberIds.contains(row.id)) row,
    ];
    return Scaffold(
      key: const Key('family-landing'),
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.familyLanding,
        familyName: family?.name ?? 'Family',
        families: _families,
        currentFamilyId: _familyId,
        onFamilySelected: (id) {
          _selectFamily(id);
        },
        stewarded: _stewarded,
        relatedFamilies: related,
        canWrite: _canWrite,
        onInvite: _canWrite ? _openInvite : null,
        onStartTimeline: _canWrite ? _startTimeline : null,
        manageApi: widget.manageApi,
      ),
      body: _loading
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: AlbumColumn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      familyName: family?.name ?? 'Family',
                      bytes: _coverBytes,
                      canEdit: _canEditCover,
                      onEdit: _editCover,
                    ),
                    const SizedBox(height: 28),
                    _LatestShelf(
                      familyName: family?.name ?? 'Family',
                      stories: _latest,
                      thumbs: _thumbs,
                      onOpen: _openStory,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openStory(Story story) async {
    if (GoRouter.maybeOf(context) == null) return;
    await context.push(
      AppRoutes.storyPath(story.id),
      extra: storyModalExtra,
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
                    ? Column(
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
                      )
                    : Image.memory(bytes!, fit: BoxFit.cover),
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

class _LatestShelf extends StatelessWidget {
  const _LatestShelf({
    required this.familyName,
    required this.stories,
    required this.thumbs,
    required this.onOpen,
  });

  final String familyName;
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
          SizedBox(
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
          ),
        const SizedBox(height: 16),
        _TimelineCta(familyName: familyName),
      ],
    );
  }
}

/// Centered terracotta pill. Rule 7′: same treatment as New story, no plus.
class _TimelineCta extends StatelessWidget {
  const _TimelineCta({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    final label = 'View a Timeline of Stories for $familyName';
    return LayoutBuilder(
      builder: (context, constraints) {
        final textMax = (constraints.maxWidth - 32).clamp(0.0, double.infinity);
        return Align(
          alignment: Alignment.center,
          child: Tooltip(
            message: label,
            child: FilledButton(
              key: const Key('family-landing-view-all'),
              onPressed: () => context.go(AppRoutes.timeline),
              style: FilledButton.styleFrom(
                backgroundColor: albumTerracotta,
                foregroundColor: albumParchment,
                elevation: 1,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textMax),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  semanticsLabel: label,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: albumParchment,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: albumParchment,
                    child: thumb == null
                        ? const SizedBox.expand()
                        : Image.memory(thumb!, fit: BoxFit.cover),
                  ),
                ),
              ),
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

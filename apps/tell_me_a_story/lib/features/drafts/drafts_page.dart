import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_chrome.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../invites/invite_modal.dart';
import '../stories/timeframe_chips.dart';

enum _DraftsFilter {
  all,
  missingText,
  missingPeople,
  missingPlace,
  missingPhotos,
  readyToPublish,
}

/// Author-only draft list at `/drafts` (missing-field chips + discard).
class DraftsPage extends StatefulWidget {
  const DraftsPage({
    super.key,
    this.inviteApi,
    this.storiesApi,
    this.photosApi,
    this.familiesApi,
  });

  final InviteGateway? inviteApi;
  final StoriesGateway? storiesApi;
  final PhotosGateway? photosApi;
  final FamiliesGateway? familiesApi;

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  late final InviteGateway _invite;
  StoriesGateway? _storiesOverride;
  PhotosGateway? _photosOverride;

  var _loading = true;
  var _loadError = false;
  var _busy = false;
  String? _familyId;
  List<Story> _drafts = const [];
  var _filter = _DraftsFilter.all;
  List<MemberFamily> _families = const [];

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PhotosGateway get _photos =>
      widget.photosApi ?? (_photosOverride ??= PhotosApi());

  @override
  void initState() {
    super.initState();
    _invite = widget.inviteApi ?? InviteApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final familyId = _familyId ?? await _invite.currentFamilyId();
      if (!mounted) return;
      if (familyId == null) {
        setState(() {
          _familyId = null;
          _drafts = const [];
          _loading = false;
        });
        return;
      }
      final drafts = await _stories.listMyDrafts(familyId);
      if (!mounted) return;
      setState(() {
        _familyId = familyId;
        _drafts = drafts;
        _loading = false;
      });
      await _loadFamilies();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _loadFamilies() async {
    List<MemberFamily> rows = const [];
    try {
      if (widget.familiesApi != null) {
        rows = await widget.familiesApi!.listMine();
      } else if (widget.inviteApi != null || widget.storiesApi != null) {
        final id = _familyId;
        if (id != null) {
          rows = [
            MemberFamily(id: id, name: 'Family', createdAt: DateTime.utc(2020)),
          ];
        }
      } else {
        rows = await FamiliesApi().listMine();
      }
    } catch (_) {
      rows = const [];
    }
    if (!mounted) return;
    if (rows.isEmpty && _familyId != null) {
      rows = [
        MemberFamily(
          id: _familyId!,
          name: 'Family',
          createdAt: DateTime.utc(2020),
        ),
      ];
    }
    setState(() => _families = rows);
  }

  Future<void> _selectFamily(String id) async {
    FamilySelection.remember(id);
    if (id == _familyId) return;
    setState(() => _familyId = id);
    await _reload();
  }

  String get _familyName {
    for (final family in _families) {
      if (family.id == _familyId) return family.name;
    }
    return 'Family';
  }

  Future<void> _openInvite() async {
    var familyId = _familyId;
    if (familyId == null) {
      familyId = await _invite.currentFamilyId();
    }
    if (familyId == null) {
      familyId = await _invite.createFamily('Family');
      if (!mounted) return;
      setState(() => _familyId = familyId);
    }
    if (!mounted) return;
    await InviteModal.show(
      context,
      familyId: familyId,
      familyName: _familyName,
      api: _invite,
    );
  }

  List<Story> get _visible {
    return [
      for (final story in _drafts)
        if (_matchesFilter(story, _filter)) story,
    ];
  }

  void _continueWriting(Story story) {
    context.push('${AppRoutes.newStory}?draft=${story.id}');
  }

  Future<void> _discard(Story story) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final familyId = _familyId ?? story.familyId;
      await _photos.deleteAllForStory(familyId: familyId, storyId: story.id);
      await _stories.discard(story.id);
      if (!mounted) return;
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t discard draft. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AlbumHeader(
        page: AlbumHeaderPage.drafts,
        familyName: _familyName,
        families: _families,
        currentFamilyId: _familyId,
        onFamilySelected: _selectFamily,
        onInvite: _openInvite,
      ),
      body: SafeArea(
        child: AlbumColumn(
          maxWidth: 1080,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('All', _DraftsFilter.all),
                    _filterChip('Missing text', _DraftsFilter.missingText),
                    _filterChip('Missing people', _DraftsFilter.missingPeople),
                    _filterChip('Missing place', _DraftsFilter.missingPlace),
                    _filterChip('Missing photos', _DraftsFilter.missingPhotos),
                    _filterChip(
                      'Ready to publish',
                      _DraftsFilter.readyToPublish,
                    ),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: Text('Loading drafts…'));
    }
    if (_loadError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Couldn’t load drafts. Try again.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_drafts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No drafts yet. Stories you’re still writing will show up here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final rows = _visible;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        const pad = 20.0;
        final inner = constraints.maxWidth - pad * 2;
        final tileWidth = (inner - 16 * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final story in rows)
                SizedBox(
                  width: tileWidth,
                  child: _DraftRow(
                    story: story,
                    onContinue: _busy ? null : () => _continueWriting(story),
                    onDiscard: _busy ? null : () => _discard(story),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, _DraftsFilter value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.story,
    required this.onContinue,
    required this.onDiscard,
  });

  final Story story;
  final VoidCallback? onContinue;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final excerpt = _bodyExcerpt(story);
    return KeyedSubtree(
      key: Key('draft-row-${story.id}'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(albumCardRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142C2416),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _timeframeLabel(story),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(label: _statusPill(story)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                excerpt,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 18, height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onContinue,
                child: const Text('Continue writing'),
              ),
              TextButton(
                onPressed: onDiscard,
                child: const Text('Discard draft'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumSage.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

/// One status for the card. Filter chips still expose every missing field.
String _statusPill(Story story) {
  final ready = publishReadiness(
    title: story.title,
    body: story.body,
    timeframeStart: story.timeframeStart,
    personIds: story.personIds,
    placeId: story.placeId,
  );
  if (ready.canPublish) return 'Ready to publish';
  if (!ready.hasTitle) return 'Missing title';
  if (!ready.hasBody) return 'Missing text';
  if (!ready.hasPerson) return 'Missing people';
  if (!ready.hasPlace) return 'Missing place';
  if (story.photoCount <= 0) return 'Missing photos';
  return 'Draft';
}

bool _matchesFilter(Story story, _DraftsFilter filter) {
  final ready = publishReadiness(
    title: story.title,
    body: story.body,
    timeframeStart: story.timeframeStart,
    personIds: story.personIds,
    placeId: story.placeId,
  );
  return switch (filter) {
    _DraftsFilter.all => true,
    _DraftsFilter.missingText => !ready.hasBody,
    _DraftsFilter.missingPeople => !ready.hasPerson,
    _DraftsFilter.missingPlace => !ready.hasPlace,
    _DraftsFilter.missingPhotos => story.photoCount <= 0,
    _DraftsFilter.readyToPublish => ready.canPublish,
  };
}

String _bodyExcerpt(Story story) {
  final title = story.title?.trim() ?? '';
  return title.isEmpty ? 'Untitled' : title;
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

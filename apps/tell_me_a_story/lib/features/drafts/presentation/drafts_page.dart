import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/publish_readiness.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/drafts/presentation/drafts_providers.dart';
import 'package:tell_me_a_story/features/family/presentation/start_timeline_dialog.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal.dart';

enum _DraftsFilter {
  all,
  missingText,
  missingPeople,
  missingPlace,
  missingPhotos,
  readyToPublish,
}

/// Header family state: loaded rows (or the current-family fallback row),
/// stewarded families and the ids the user can write in.
class _FamilyView {
  const _FamilyView({
    required this.families,
    required this.stewarded,
    required this.memberIds,
  });

  factory _FamilyView.of(
    AsyncValue<DraftsFamilies> loaded,
    Set<String> membership,
    String? familyId,
  ) {
    if (loaded.hasError) {
      return _FamilyView(
        families: _fallbackRows(const [], familyId),
        stewarded: const [],
        memberIds: const {},
      );
    }
    final value = loaded.value;
    if (value == null) {
      return _FamilyView(
        families: const [],
        stewarded: const [],
        memberIds: membership,
      );
    }
    return _FamilyView(
      families: _fallbackRows(value.member, familyId),
      stewarded: value.stewarded,
      memberIds: membership,
    );
  }

  final List<MemberFamily> families;
  final List<StewardFamily> stewarded;
  final Set<String> memberIds;

  bool isMember(String? familyId) =>
      familyId != null && memberIds.contains(familyId);

  String nameOf(String? familyId) {
    for (final family in families) {
      if (family.id == familyId) return family.name;
    }
    return 'Family';
  }
}

List<MemberFamily> _fallbackRows(List<MemberFamily> rows, String? familyId) {
  if (rows.isNotEmpty || familyId == null) return rows;
  return [
    MemberFamily(id: familyId, name: 'Family', createdAt: DateTime.utc(2020)),
  ];
}

/// Author-only draft list at `/drafts` (missing-field chips + discard).
class DraftsPage extends ConsumerStatefulWidget {
  const DraftsPage({super.key});

  @override
  ConsumerState<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends ConsumerState<DraftsPage> {
  var _busy = false;
  var _filter = _DraftsFilter.all;

  String? get _familyId => ref.read(familySelectionProvider);

  _FamilyView get _familyView => _FamilyView.of(
    ref.read(draftsFamiliesProvider),
    ref.read(familyMembershipProvider).ids,
    _familyId,
  );

  void _reload() {
    ref.invalidate(myDraftsProvider);
    ref.invalidate(draftsFamiliesProvider);
  }

  Future<void> _startTimeline() async {
    final id = _familyId;
    if (id == null || !_familyView.isMember(id) || !mounted) return;
    final userId = ref.read(appSessionProvider).currentUserId;
    if (userId == null) return;
    final published = await ref
        .read(storiesRepositoryProvider)
        .listPublished(id);
    if (!mounted) return;
    final created = await showStartTimelineDialog(
      context,
      parentId: id,
      parentName: _familyView.nameOf(id),
      stories: [
        for (final story in published)
          if (story.status == StoryStatus.published) story,
      ],
      currentUserId: userId,
      onWriteStory: () {
        if (!mounted) return;
        GoRouter.of(context).push('${AppRoutes.newStory}?newTimelineFrom=$id');
      },
    );
    if (created == null || !mounted) return;
    _reload();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} timeline created')));
  }

  void _selectFamily(String id) {
    final previous = _familyId;
    ref.read(familySelectionProvider.notifier).remember(id);
    if (id == previous) return;
    _reload();
  }

  Future<void> _openInvite() async {
    final invite = ref.read(inviteRepositoryProvider);
    var familyId = _familyId;
    familyId ??= await invite.currentFamilyId();
    if (familyId == null) {
      familyId = await invite.createFamily('Family');
      if (!mounted) return;
      ref.read(familySelectionProvider.notifier).remember(familyId);
    }
    if (!mounted) return;
    await InviteModal.show(
      context,
      familyId: familyId,
      familyName: _familyView.nameOf(familyId),
    );
  }

  void _continueWriting(Story story) {
    context.push('${AppRoutes.newStory}?draft=${story.id}');
  }

  Future<void> _discard(Story story) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(storiesRepositoryProvider).discard(story.id);
      if (!mounted) return;
      _reload();
    } catch (_) {
      // Boundary: any discard failure shows the locked snack copy.
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
    final familyId = ref.watch(familySelectionProvider);
    final view = _FamilyView.of(
      ref.watch(draftsFamiliesProvider),
      ref.watch(familyMembershipProvider).ids,
      familyId,
    );
    final member = view.isMember(familyId);
    return Scaffold(
      appBar: AlbumHeader(
        page: AlbumHeaderPage.drafts,
        familyName: view.nameOf(familyId),
        families: view.families,
        currentFamilyId: familyId,
        onFamilySelected: _selectFamily,
        stewarded: view.stewarded,
        canWrite: member,
        onInvite: member ? _openInvite : null,
        onStartTimeline: member ? _startTimeline : null,
      ),
      body: SafeArea(
        child: AlbumColumn(
          maxWidth: 1080,
          child: _DraftsContent(
            drafts: ref.watch(myDraftsProvider),
            filter: _filter,
            onFilter: (value) => setState(() => _filter = value),
            onContinue: _busy ? null : _continueWriting,
            onDiscard: _busy ? null : _discard,
          ),
        ),
      ),
    );
  }
}

class _DraftsContent extends StatelessWidget {
  const _DraftsContent({
    required this.drafts,
    required this.filter,
    required this.onFilter,
    required this.onContinue,
    required this.onDiscard,
  });

  final AsyncValue<MyDrafts> drafts;
  final _DraftsFilter filter;
  final ValueChanged<_DraftsFilter> onFilter;
  final ValueChanged<Story>? onContinue;
  final ValueChanged<Story>? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterChips(selected: filter, onSelected: onFilter),
        Expanded(
          child: _DraftsBody(
            drafts: drafts,
            filter: filter,
            onContinue: onContinue,
            onDiscard: onDiscard,
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _DraftsFilter selected;
  final ValueChanged<_DraftsFilter> onSelected;

  static const _labels = {
    _DraftsFilter.all: 'All',
    _DraftsFilter.missingText: 'Missing text',
    _DraftsFilter.missingPeople: 'Missing people',
    _DraftsFilter.missingPlace: 'Missing place',
    _DraftsFilter.missingPhotos: 'Missing photos',
    _DraftsFilter.readyToPublish: 'Ready to publish',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(key: value, value: label) in _labels.entries)
            FilterChip(
              label: Text(label),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
            ),
        ],
      ),
    );
  }
}

class _DraftsBody extends StatelessWidget {
  const _DraftsBody({
    required this.drafts,
    required this.filter,
    required this.onContinue,
    required this.onDiscard,
  });

  final AsyncValue<MyDrafts> drafts;
  final _DraftsFilter filter;
  final ValueChanged<Story>? onContinue;
  final ValueChanged<Story>? onDiscard;

  @override
  Widget build(BuildContext context) {
    return drafts.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: Text('Loading drafts…')),
      error: (error, stackTrace) =>
          const _CenteredMessage('Couldn’t load drafts. Try again.'),
      data: (data) {
        if (data.drafts.isEmpty) {
          return const _CenteredMessage(
            'No drafts yet. Stories you’re still writing will show up here.',
          );
        }
        return _DraftGrid(
          stories: [
            for (final story in data.drafts)
              if (_matchesFilter(story, filter)) story,
          ],
          onContinue: onContinue,
          onDiscard: onDiscard,
        );
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DraftGrid extends StatelessWidget {
  const _DraftGrid({
    required this.stories,
    required this.onContinue,
    required this.onDiscard,
  });

  final List<Story> stories;
  final ValueChanged<Story>? onContinue;
  final ValueChanged<Story>? onDiscard;

  @override
  Widget build(BuildContext context) {
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
              for (final story in stories)
                SizedBox(
                  width: tileWidth,
                  child: _DraftRow(
                    story: story,
                    onContinue: _bind(onContinue, story),
                    onDiscard: _bind(onDiscard, story),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

VoidCallback? _bind(ValueChanged<Story>? callback, Story story) {
  if (callback == null) return null;
  return () => callback(story);
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
          child: _DraftRowContent(
            story: story,
            onContinue: onContinue,
            onDiscard: onDiscard,
          ),
        ),
      ),
    );
  }
}

class _DraftRowContent extends StatelessWidget {
  const _DraftRowContent({
    required this.story,
    required this.onContinue,
    required this.onDiscard,
  });

  final Story story;
  final VoidCallback? onContinue;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _timeframeLabel(story),
                style: textTheme.labelLarge?.copyWith(
                  color: story.timeframeStart == null
                      ? albumInk.withValues(alpha: 0.55)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _StatusPill(label: _statusPill(story)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _bodyExcerpt(story),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.45),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onContinue,
          child: const Text('Continue writing'),
        ),
        TextButton(onPressed: onDiscard, child: const Text('Discard draft')),
      ],
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

PublishReadiness _readiness(Story story) => publishReadiness(
  title: story.title,
  body: story.body,
  timeframeStart: story.timeframeStart,
  personIds: story.personIds,
  placeId: story.placeId,
);

/// One status for the card. Filter chips still expose every missing field.
String _statusPill(Story story) {
  final ready = _readiness(story);
  if (ready.canPublish) return 'Ready to publish';
  if (!ready.hasTitle) return 'Missing title';
  if (!ready.hasBody) return 'Missing text';
  if (!ready.hasPerson) return 'Missing people';
  if (!ready.hasPlace) return 'Missing place';
  if (story.photoCount <= 0) return 'Missing photos';
  return 'Draft';
}

bool _matchesFilter(Story story, _DraftsFilter filter) {
  final ready = _readiness(story);
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
  if (story.timeframeStart == null) return 'No date yet';
  return storyDateLabelFor(story);
}

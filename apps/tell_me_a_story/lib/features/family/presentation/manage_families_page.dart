import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';
import 'package:tell_me_a_story/core/domain/family_roster.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/recovery_window.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';
import 'package:tell_me_a_story/core/widgets/family/family_tree_order.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_providers.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_start_timeline.dart';
import 'package:tell_me_a_story/features/family/presentation/start_family_dialog.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal.dart';

const _startFamilyTooltip =
    "Start a family that isn't linked to your existing ones";

/// Shown when the hub load fails: today's empty member hub.
const _emptyHub = ManageFamiliesHub(
  directory: FamilyDirectory(active: [], recoverable: []),
  families: [],
  stewarded: [],
);

/// Stitch hub `622ceebb3b434b6c88143f888cca8ef9`.
class ManageFamiliesPage extends ConsumerStatefulWidget {
  const ManageFamiliesPage({super.key, this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  ConsumerState<ManageFamiliesPage> createState() => _ManageFamiliesPageState();
}

class _ManageFamiliesPageState extends ConsumerState<ManageFamiliesPage> {
  /// Family picked in the header or for an invite since the last load.
  String? _picked;

  ManageFamiliesHub? get _loaded => ref.read(manageFamiliesHubProvider).value;

  String? _sessionOf(ManageFamiliesHub? loaded, String? remembered) {
    if (_picked case final picked?) return picked;
    if (loaded == null) return null;
    return loaded.sessionFamilyId ?? remembered;
  }

  String? get _sessionFamilyId =>
      _sessionOf(_loaded, ref.read(familySelectionProvider));

  void _reload() {
    if (!mounted) return;
    setState(() => _picked = null);
    ref.invalidate(manageFamiliesHubProvider);
  }

  Future<void> _startTimeline() async {
    final id = _sessionFamilyId;
    final hub = _loaded ?? _emptyHub;
    if (id == null || !_isMember(hub, id)) return;
    final userId = ref.read(appSessionProvider).currentUserId;
    if (userId == null) return;
    await startManageTimeline(
      context,
      ref,
      familyId: id,
      familyName: _sessionName(hub, id),
      userId: userId,
      onCreated: _reload,
    );
  }

  Future<void> _start() async {
    final id = await showStartFamilyDialog(context);
    if (id == null || !mounted) return;
    ref.read(familySelectionProvider.notifier).remember(id);
    context.go(AppRoutes.familyLanding);
  }

  Future<void> _recover(FamilyRoster family) async {
    try {
      await ref.read(manageFamiliesRepositoryProvider).recoverFamily(family.id);
      _reload();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _invite() async {
    final id =
        _sessionFamilyId ??
        await ref.read(inviteRepositoryProvider).currentFamilyId();
    if (id == null || !mounted) return;
    if (_sessionFamilyId != id) setState(() => _picked = id);
    await InviteModal.show(
      context,
      familyId: id,
      familyName: _sessionName(_loaded ?? _emptyHub, id),
    );
  }

  void _select(String id) {
    ref.read(familySelectionProvider.notifier).remember(id);
    setState(() => _picked = id);
  }

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(manageFamiliesHubProvider);
    final loaded = hubState.value;
    final hub = loaded ?? _emptyHub;
    final session = _sessionOf(loaded, ref.watch(familySelectionProvider));
    final member = _isMember(hub, session);
    return Scaffold(
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.manageFamilies,
        familyName: _sessionName(hub, session),
        families: hub.families,
        currentFamilyId: session,
        onFamilySelected: _select,
        stewarded: hub.stewarded,
        canWrite: member,
        onInvite: member ? _invite : null,
        onStartTimeline: member ? _startTimeline : null,
        onLogout: widget.onLogout,
      ),
      body: hubState.when(
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _HubList(hub: _emptyHub, onStart: _start, onRecover: _recover),
        data: (data) =>
            _HubList(hub: data, onStart: _start, onRecover: _recover),
      ),
    );
  }
}

bool _isMember(ManageFamiliesHub hub, String? id) =>
    id != null && hub.families.any((family) => family.id == id);

String _sessionName(ManageFamiliesHub hub, String? id) {
  for (final family in hub.families) {
    if (family.id == id) return family.name;
  }
  for (final family in hub.directory.active) {
    if (family.id == id) return family.name;
  }
  return 'Family';
}

bool _stewards(FamilyRoster family) =>
    family.role == 'owner' || family.role == 'co_owner';

class _HubList extends StatelessWidget {
  const _HubList({
    required this.hub,
    required this.onStart,
    required this.onRecover,
  });

  final ManageFamiliesHub hub;
  final VoidCallback onStart;
  final ValueChanged<FamilyRoster> onRecover;

  @override
  Widget build(BuildContext context) {
    final ownerView = hub.stewarded.any((f) => f.countsForManage());
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 56),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: ownerView
                ? _OwnerHub(
                    directory: hub.directory,
                    onStart: onStart,
                    onRecover: onRecover,
                  )
                : _MemberHub(families: hub.families, onStart: onStart),
          ),
        ),
      ],
    );
  }
}

class _OwnerHub extends StatelessWidget {
  const _OwnerHub({
    required this.directory,
    required this.onStart,
    required this.onRecover,
  });

  final FamilyDirectory directory;
  final VoidCallback onStart;
  final ValueChanged<FamilyRoster> onRecover;

  @override
  Widget build(BuildContext context) {
    final owned = [
      for (final family in directory.active)
        if (_stewards(family)) family,
    ];
    final recoverable = [
      for (final family in directory.recoverable)
        if (family.deletedAt case final deletedAt?
            when _stewards(family) && isInsideRecoveryWindow(deletedAt))
          family,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OwnerTitleRow(onStart: onStart),
        const SizedBox(height: 48),
        _FamiliesHeading(count: owned.length),
        const SizedBox(height: 16),
        for (final family in owned) ...[
          _ActiveCard(family: family),
          const SizedBox(height: 16),
        ],
        if (recoverable.isNotEmpty)
          _RecoverableSection(families: recoverable, onRecover: onRecover),
      ],
    );
  }
}

class _OwnerTitleRow extends StatelessWidget {
  const _OwnerTitleRow({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_HubTitle()],
          ),
        ),
        const SizedBox(width: 16),
        _StartButton(onStart: onStart),
      ],
    );
  }
}

class _RecoverableSection extends StatelessWidget {
  const _RecoverableSection({required this.families, required this.onRecover});

  final List<FamilyRoster> families;
  final ValueChanged<FamilyRoster> onRecover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'Recoverable (60 days)',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        for (final family in families) ...[
          _RecoverCard(family: family, onRecover: () => onRecover(family)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

const _hubVariant = albumInk;
const _hubLine = Color(0xFFB9B0AD);
const _hubHigh = Color(0xFFF0E6E3);
const _hubContainer = Color(0xFFF5ECE9);

/// "Your families" with the active-count pill.
class _FamiliesHeading extends StatelessWidget {
  const _FamiliesHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Your families',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _hubHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count active',
            style: GoogleFonts.sourceSans3(color: _hubVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _MemberHub extends StatelessWidget {
  const _MemberHub({required this.families, required this.onStart});

  final List<MemberFamily> families;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final rows = nestFamilies(families);
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HubTitle(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _StartButton(onStart: onStart),
              ),
            ],
          )
        else
          _OwnerTitleRow(onStart: onStart),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 48),
          _FamiliesHeading(count: rows.length),
          const SizedBox(height: 16),
          _MemberRows(rows: rows),
        ],
      ],
    );
  }
}

class _MemberRows extends StatelessWidget {
  const _MemberRows({required this.rows});

  final List<FamilyMenuRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hubLine.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: albumInk.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [for (final row in rows) _MemberRow(row: row)]),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _startFamilyTooltip,
      child: FilledButton(
        key: const Key('manage-families-start'),
        onPressed: onStart,
        style: FilledButton.styleFrom(
          backgroundColor: albumTerracotta,
          foregroundColor: const Color(0xFFFFF6F3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.sourceSans3(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: PlusLabel(
          label: 'Start a family',
          onTerracotta: true,
          style: GoogleFonts.sourceSans3(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFFF6F3),
          ),
        ),
      ),
    );
  }
}

class _HubTitle extends StatelessWidget {
  const _HubTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Manage families',
      style: GoogleFonts.newsreader(
        color: albumInk,
        fontSize: 48,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.6,
        height: 1.1,
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.row});

  final FamilyMenuRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = row.family;
    return InkWell(
      key: Key('manage-families-member-${family.id}'),
      onTap: () {
        ref.read(familySelectionProvider.notifier).remember(family.id);
        context.go(AppRoutes.familyLanding);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              FamilyIndentGuide(depth: row.depth, height: 56),
              FamilyMonogram(
                key: Key('manage-families-member-monogram-${family.id}'),
                name: family.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  family.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    color: albumInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                familyRoleLabel(family.role ?? 'member'),
                style: GoogleFonts.sourceSans3(color: albumSage, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.family});

  final FamilyRoster family;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hubLine.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: albumInk.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            FamilyMonogram(
              key: Key('hub-monogram-${family.id}'),
              name: family.name,
              size: 48,
            ),
            const SizedBox(width: 16),
            Expanded(child: _ActiveSummary(family: family)),
            _EnterButton(familyId: family.id),
          ],
        ),
      ),
    );
  }
}

class _ActiveSummary extends StatelessWidget {
  const _ActiveSummary({required this.family});

  final FamilyRoster family;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              family.name,
              style: GoogleFonts.newsreader(
                color: albumInk,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _hubContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                familyRoleLabel(family.role),
                style: GoogleFonts.sourceSans3(
                  color: _hubVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${family.memberCount} members · ${family.publishedCount} stories',
          style: GoogleFonts.literata(color: _hubVariant, fontSize: 14),
        ),
      ],
    );
  }
}

class _EnterButton extends StatelessWidget {
  const _EnterButton({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: Key('manage-family-enter-$familyId'),
      onPressed: () => context.push(AppRoutes.manageFamilyPath(familyId)),
      style: TextButton.styleFrom(
        foregroundColor: albumTerracotta,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter',
            style: GoogleFonts.sourceSans3(
              color: albumTerracotta,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    );
  }
}

class _RecoverCard extends StatelessWidget {
  const _RecoverCard({required this.family, required this.onRecover});

  final FamilyRoster family;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hubLine.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            FamilyMonogram(
              key: Key('hub-monogram-${family.id}'),
              name: family.name,
              size: 48,
            ),
            const SizedBox(width: 16),
            Expanded(child: _RecoverSummary(family: family)),
            _RecoverButton(familyId: family.id, onRecover: onRecover),
          ],
        ),
      ),
    );
  }
}

class _RecoverSummary extends StatelessWidget {
  const _RecoverSummary({required this.family});

  final FamilyRoster family;

  @override
  Widget build(BuildContext context) {
    final deleted = family.deletedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          family.name,
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          deleted == null ? '' : deletedRecoveryLine(deleted),
          style: GoogleFonts.literata(color: _hubVariant, fontSize: 14),
        ),
      ],
    );
  }
}

class _RecoverButton extends StatelessWidget {
  const _RecoverButton({required this.familyId, required this.onRecover});

  final String familyId;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: Key('manage-family-recover-$familyId'),
      onPressed: onRecover,
      style: FilledButton.styleFrom(
        backgroundColor: albumSage,
        foregroundColor: const Color(0xFFFFF7F5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      icon: const Icon(Icons.settings_backup_restore, size: 16),
      label: const Text('Recover'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/manage_families_api.dart';
import '../../data/recovery_window.dart';
import '../invites/invite_modal.dart';
import 'family_role.dart';
import 'start_family_dialog.dart';

/// Stitch hub `622ceebb3b434b6c88143f888cca8ef9`.
class ManageFamiliesPage extends StatefulWidget {
  const ManageFamiliesPage({
    super.key,
    this.directoryApi,
    this.familiesApi,
    this.manageApi,
    this.inviteApi,
    this.onLogout,
  });

  final FamilyDirectoryGateway? directoryApi;
  final FamiliesGateway? familiesApi;
  final ManageFamiliesGateway? manageApi;
  final InviteGateway? inviteApi;
  final Future<void> Function()? onLogout;

  @override
  State<ManageFamiliesPage> createState() => _ManageFamiliesPageState();
}

class _ManageFamiliesPageState extends State<ManageFamiliesPage> {
  FamilyDirectory _rows = const FamilyDirectory(active: [], recoverable: []);
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  String? _sessionFamilyId;
  var _loading = true;

  FamilyDirectoryGateway get _directoryApi =>
      widget.directoryApi ?? FamiliesApi();

  ManageFamiliesGateway get _manage => widget.manageApi ?? ManageFamiliesApi();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final directory = await _directoryApi.listDirectory();
      final menu = await _loadMenu();
      final session = widget.inviteApi == null
          ? FamilySelection.id
          : await widget.inviteApi!.currentFamilyId();
      if (!mounted) return;
      setState(() {
        _rows = directory;
        _families = menu.families;
        _stewarded = menu.stewarded;
        _sessionFamilyId = session ?? FamilySelection.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<({List<MemberFamily> families, List<StewardFamily> stewarded})>
  _loadMenu() async {
    final api = widget.familiesApi;
    if (api != null) {
      return (
        families: await api.listMine(),
        stewarded: await api.listStewarded(),
      );
    }
    if (widget.directoryApi != null) {
      return (
        families: const <MemberFamily>[],
        stewarded: const <StewardFamily>[],
      );
    }
    final live = FamiliesApi();
    return (
      families: await live.listMine(),
      stewarded: await live.listStewarded(),
    );
  }

  List<FamilyRoster> get _ownedActive => [
    for (final family in _rows.active)
      if (family.role == 'owner' || family.role == 'co_owner') family,
  ];

  List<FamilyRoster> get _recoverableNow => [
    for (final family in _rows.recoverable)
      if ((family.role == 'owner' || family.role == 'co_owner') &&
          family.deletedAt != null &&
          isInsideRecoveryWindow(family.deletedAt!))
        family,
  ];

  String get _sessionName {
    for (final family in _families) {
      if (family.id == _sessionFamilyId) return family.name;
    }
    for (final family in _rows.active) {
      if (family.id == _sessionFamilyId) return family.name;
    }
    return 'Family';
  }

  Future<void> _start() async {
    final id = await showStartFamilyDialog(context, api: _manage);
    if (id == null || !mounted) return;
    FamilySelection.remember(id);
    context.go(AppRoutes.timeline);
  }

  Future<void> _recover(FamilyRoster family) async {
    try {
      await _manage.recoverFamily(family.id);
      await _load();
    } on ManageFamiliesException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _invite() async {
    final id = _sessionFamilyId;
    if (id == null) return;
    await InviteModal.show(
      context,
      familyId: id,
      familyName: _sessionName,
      api: widget.inviteApi,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: albumParchment,
      appBar: AlbumHeader(
        page: AlbumHeaderPage.manageFamilies,
        familyName: _sessionName,
        families: _families,
        currentFamilyId: _sessionFamilyId,
        onFamilySelected: (id) {
          FamilySelection.remember(id);
          setState(() => _sessionFamilyId = id);
        },
        stewarded: _stewarded,
        manageApi: widget.manageApi,
        onInvite: _invite,
        onLogout: widget.onLogout,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 56),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manage families',
                                    style: GoogleFonts.newsreader(
                                      color: albumInk,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.6,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Switch between your active family archives or create a new shared space.',
                                    style: GoogleFonts.literata(
                                      color: _hubVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              key: const Key('manage-families-start'),
                              onPressed: _start,
                              style: FilledButton.styleFrom(
                                backgroundColor: albumTerracotta,
                                foregroundColor: const Color(0xFFFFF6F3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: GoogleFonts.sourceSans3(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              icon: const Icon(Icons.add_circle, size: 20),
                              label: const Text('+ Start a family'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Row(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _hubHigh,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_ownedActive.length} active',
                                style: GoogleFonts.sourceSans3(
                                  color: _hubVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final family in _ownedActive) ...[
                          _ActiveCard(family: family),
                          const SizedBox(height: 16),
                        ],
                        if (_recoverableNow.isNotEmpty) ...[
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
                          for (final family in _recoverableNow) ...[
                            _RecoverCard(
                              family: family,
                              onRecover: () => _recover(family),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

const _hubVariant = Color(0xFF655E5B);
const _hubLine = Color(0xFFB9B0AD);
const _hubHigh = Color(0xFFF0E6E3);
const _hubContainer = Color(0xFFF5ECE9);

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
            Expanded(
              child: Column(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
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
                    style: GoogleFonts.literata(
                      color: _hubVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: Key('manage-family-enter-${family.id}'),
              onPressed: () =>
                  context.push(AppRoutes.manageFamilyPath(family.id)),
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
            ),
          ],
        ),
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
    final deleted = family.deletedAt;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF2F0),
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
            Expanded(
              child: Column(
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
                    style: GoogleFonts.literata(
                      color: _hubVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: Key('manage-family-recover-${family.id}'),
              onPressed: onRecover,
              style: FilledButton.styleFrom(
                backgroundColor: albumSage,
                foregroundColor: const Color(0xFFFFF7F5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.sourceSans3(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              icon: const Icon(Icons.settings_backup_restore, size: 16),
              label: const Text('Recover'),
            ),
          ],
        ),
      ),
    );
  }
}

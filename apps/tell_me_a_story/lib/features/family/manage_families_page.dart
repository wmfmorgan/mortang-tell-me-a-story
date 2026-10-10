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
import '../invites/invite_modal.dart';
import 'family_role.dart';
import 'start_family_dialog.dart';

/// Stitch hub `b429823c1f6a44aea297aaeef195bedd`.
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
      final families = widget.familiesApi == null
          ? const <MemberFamily>[]
          : await widget.familiesApi!.listMine();
      final session = widget.inviteApi == null
          ? FamilySelection.id
          : await widget.inviteApi!.currentFamilyId();
      if (!mounted) return;
      setState(() {
        _rows = directory;
        _families = families;
        _sessionFamilyId = session ?? FamilySelection.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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
        page: AlbumHeaderPage.timeline,
        familyName: _sessionName,
        families: _families,
        currentFamilyId: _sessionFamilyId,
        onFamilySelected: (id) {
          FamilySelection.remember(id);
          setState(() => _sessionFamilyId = id);
        },
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
                                '${_rows.active.length} active',
                                style: GoogleFonts.sourceSans3(
                                  color: _hubVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final family in _rows.active) ...[
                          _ActiveCard(family: family),
                          const SizedBox(height: 16),
                        ],
                        if (_rows.recoverable.isNotEmpty) ...[
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
                          for (final family in _rows.recoverable) ...[
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
const _hubBlush = Color(0xFFF5DED6);
const _hubBlushInk = Color(0xFF5E4E48);
const _hubError = Color(0xFF9F403D);

class _Mark extends StatelessWidget {
  const _Mark({
    required this.icon,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.family});

  final FamilyRoster family;

  @override
  Widget build(BuildContext context) {
    final owner = family.role == 'owner';
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
            _Mark(
              icon: switch (family.role) {
                'owner' => Icons.diversity_3,
                'co_owner' => Icons.cottage,
                _ => Icons.park,
              },
              background: owner ? _hubBlush : _hubContainer,
              color: owner ? _hubBlushInk : _hubVariant,
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
            const _Mark(
              icon: Icons.folder_delete,
              background: _hubHigh,
              color: _hubError,
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

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
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Manage families',
                  style: GoogleFonts.newsreader(
                    color: albumInk,
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Switch between your active family archives or create a new shared space.',
                  style: GoogleFonts.literata(color: albumInk, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('manage-families-start'),
                    onPressed: _start,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('+ Start a family'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your families',
                  style: GoogleFonts.newsreader(
                    color: albumInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_rows.active.length} active',
                  style: GoogleFonts.sourceSans3(color: albumInk),
                ),
                const SizedBox(height: 12),
                for (final family in _rows.active) _ActiveCard(family: family),
                if (_rows.recoverable.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Recoverable (60 days)',
                    style: GoogleFonts.newsreader(
                      color: albumInk,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final family in _rows.recoverable)
                    _RecoverCard(
                      family: family,
                      onRecover: () => _recover(family),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.family});

  final FamilyRoster family;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          family.name,
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FamilyRoleChip(role: family.role),
              Text(
                '${family.memberCount} members · ${family.publishedCount} stories',
                style: GoogleFonts.sourceSans3(color: albumInk),
              ),
            ],
          ),
        ),
        trailing: TextButton(
          key: Key('manage-family-enter-${family.id}'),
          onPressed: () => context.push(AppRoutes.manageFamilyPath(family.id)),
          child: const Text('Enter'),
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
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          family.name,
          style: GoogleFonts.newsreader(color: albumInk, fontSize: 22),
        ),
        subtitle: Text(
          deleted == null ? '' : deletedRecoveryLine(deleted),
          style: GoogleFonts.sourceSans3(color: albumInk),
        ),
        trailing: TextButton(
          key: Key('manage-family-recover-${family.id}'),
          onPressed: onRecover,
          child: const Text('Recover'),
        ),
      ),
    );
  }
}

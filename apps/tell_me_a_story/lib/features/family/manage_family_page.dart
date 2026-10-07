import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/album_header.dart';
import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_avatar.dart';
import '../../data/families_api.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../../data/manage_families_api.dart';
import '../invites/invite_modal.dart';
import 'delete_family_dialog.dart';
import 'family_role.dart';
import 'transfer_ownership_dialog.dart';

/// Stitch detail `1c097b0e40cd4703a76fb8b1baf1ebc7`.
class ManageFamilyPage extends StatefulWidget {
  const ManageFamilyPage({
    super.key,
    required this.familyId,
    this.directoryApi,
    this.familiesApi,
    this.manageApi,
    this.inviteApi,
    this.onLogout,
  });

  final String familyId;
  final FamilyDirectoryGateway? directoryApi;
  final FamiliesGateway? familiesApi;
  final ManageFamiliesGateway? manageApi;
  final InviteGateway? inviteApi;
  final Future<void> Function()? onLogout;

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  FamilyDetail? _detail;
  List<MemberFamily> _families = const [];
  String? _sessionFamilyId;
  var _loading = true;
  var _missing = false;
  final _name = TextEditingController();

  FamilyDirectoryGateway get _directoryApi =>
      widget.directoryApi ?? FamiliesApi();

  ManageFamiliesGateway get _manage => widget.manageApi ?? ManageFamiliesApi();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isOwner => _detail?.myRole == 'owner';
  bool get _canAdmin => _isOwner || _detail?.myRole == 'co_owner';

  List<FamilyPerson> get _coOwners => [
    for (final person in _detail?.people ?? const <FamilyPerson>[])
      if (person.role == 'co_owner') person,
  ];

  List<FamilyPerson> get _members => [
    for (final person in _detail?.people ?? const <FamilyPerson>[])
      if (person.role == 'member') person,
  ];

  Future<void> _load() async {
    try {
      final detail = await _directoryApi.loadDetail(widget.familyId);
      final families = widget.familiesApi == null
          ? const <MemberFamily>[]
          : await widget.familiesApi!.listMine();
      final session = widget.inviteApi == null
          ? FamilySelection.id
          : await widget.inviteApi!.currentFamilyId();
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loading = false;
          _missing = true;
        });
        return;
      }
      _name.text = detail.name;
      setState(() {
        _detail = detail;
        _families = families;
        _sessionFamilyId = session ?? FamilySelection.id;
        _loading = false;
        _missing = false;
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
    return _detail?.name ?? 'Family';
  }

  Future<void> _rename() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      await _manage.renameFamily(familyId: detail.id, name: _name.text);
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _addCoOwner() async {
    final detail = _detail;
    if (detail == null || _coOwners.length >= 2) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const Key('add-co-owner-dialog'),
        title: const Text('Add co-owner'),
        children: [
          for (final person in _members)
            SimpleDialogOption(
              key: Key('add-co-owner-${person.userId}'),
              onPressed: () => Navigator.pop(context, person.userId),
              child: Text(
                person.displayName?.trim().isNotEmpty == true
                    ? person.displayName!.trim()
                    : 'Member',
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await _manage.addCoOwner(familyId: detail.id, userId: picked);
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _removeCoOwner(FamilyPerson person) async {
    final detail = _detail;
    if (detail == null) return;
    try {
      await _manage.removeCoOwner(familyId: detail.id, userId: person.userId);
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _removeMember(FamilyPerson person) async {
    final detail = _detail;
    if (detail == null) return;
    try {
      await _manage.removeMember(familyId: detail.id, userId: person.userId);
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _transfer() async {
    final detail = _detail;
    if (detail == null || _coOwners.isEmpty) return;
    final choice = await showTransferOwnershipDialog(
      context,
      familyName: detail.name,
      coOwners: _coOwners,
    );
    if (choice == null) return;
    try {
      await _manage.transferOwnership(
        familyId: detail.id,
        newOwnerUserId: choice.newOwnerUserId,
        formerOwnerBecomes: choice.formerOwnerBecomes,
      );
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _delete() async {
    final detail = _detail;
    if (detail == null) return;
    final confirmed = await showDeleteFamilyDialog(
      context,
      familyName: detail.name,
    );
    if (!confirmed || !mounted) return;
    try {
      await _manage.softDeleteFamily(detail.id);
      FamilySelection.forget(detail.id);
      if (!mounted) return;
      context.go(AppRoutes.manageFamilies);
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _inviteThisFamily() async {
    final detail = _detail;
    if (detail == null) return;
    await InviteModal.show(
      context,
      familyId: detail.id,
      familyName: detail.name,
      api: widget.inviteApi,
    );
  }

  Future<void> _inviteSession() async {
    final id = _sessionFamilyId;
    if (id == null) return;
    await InviteModal.show(
      context,
      familyId: id,
      familyName: _sessionName,
      api: widget.inviteApi,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      key: const Key('manage-family-detail'),
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
        onInvite: _inviteSession,
        onLogout: widget.onLogout,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _missing || detail == null
          ? const Center(child: Text('Not found'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('manage-family-back'),
                    onPressed: () => context.go(AppRoutes.manageFamilies),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Manage families'),
                  ),
                ),
                Text(
                  detail.name,
                  style: GoogleFonts.newsreader(
                    color: albumInk,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Manage family settings, co-owners, members, and archival access permissions.',
                  style: GoogleFonts.literata(color: albumInk),
                ),
                const SizedBox(height: 24),
                if (_canAdmin) ...[
                  Text('Family Name', style: _heading),
                  Text(
                    'The primary display name for this shared family heritage archive.',
                    style: _body,
                  ),
                  TextField(
                    key: const Key('manage-family-name'),
                    controller: _name,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('manage-family-rename'),
                      onPressed: _rename,
                      child: const Text('Rename'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Your Role', style: _heading),
                Text(_roleHelp(detail.myRole), style: _body),
                const SizedBox(height: 8),
                FamilyRoleChip(role: detail.myRole),
                const SizedBox(height: 24),
                Text('Co-owners (up to two)', style: _heading),
                Text(
                  'Co-owners share full administrative privileges with the primary owner.',
                  style: _body,
                ),
                if (_canAdmin && _coOwners.length < 2)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('manage-family-add-co-owner'),
                      onPressed: _members.isEmpty ? null : _addCoOwner,
                      icon: const Icon(Icons.add),
                      label: const Text('Add co-owner'),
                    ),
                  ),
                for (final person in _coOwners)
                  _PersonRow(
                    person: person,
                    onRemove: _isOwner ? () => _removeCoOwner(person) : null,
                  ),
                Text(
                  'Co-owners have the same powers as the owner.',
                  style: _body,
                ),
                const SizedBox(height: 24),
                Text('Members', style: _heading),
                Text(
                  'Family members with access to read and contribute stories to the album.',
                  style: _body,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('manage-family-invite'),
                    onPressed: _inviteThisFamily,
                    child: const Text('Invite'),
                  ),
                ),
                for (final person in _members)
                  _PersonRow(
                    person: person,
                    onRemove: _canAdmin ? () => _removeMember(person) : null,
                  ),
                if (_isOwner && _coOwners.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Ownership Transfer', style: _heading),
                  Text(
                    'Transfer primary ownership of ${detail.name} album and archive to another co-owner.',
                    style: _body,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('manage-family-transfer'),
                      onPressed: _transfer,
                      child: const Text('Transfer ownership…'),
                    ),
                  ),
                ],
                if (_isOwner) ...[
                  const SizedBox(height: 24),
                  Text('Soft-delete this family', style: _heading),
                  Text(
                    'Hidden for 60 days, then permanently removed. Owner only. Recover from Manage families.',
                    style: _body,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('manage-family-delete'),
                      onPressed: _delete,
                      child: const Text('Delete family…'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

String _roleHelp(String role) {
  return switch (role) {
    'owner' => 'Your permission level grants full administrative controls over the family archive.',
    'co_owner' => 'Co-owners have the same powers as the owner.',
    _ =>
      'Family members with access to read and contribute stories to the album.',
  };
}

TextStyle get _heading => GoogleFonts.newsreader(
  color: albumInk,
  fontSize: 22,
  fontWeight: FontWeight.w600,
);

TextStyle get _body => GoogleFonts.literata(color: albumInk, fontSize: 15);

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, this.onRemove});

  final FamilyPerson person;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name = person.displayName?.trim().isNotEmpty == true
        ? person.displayName!.trim()
        : 'Member';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ProfileAvatar(
        size: 40,
        displayName: person.displayName,
        bytes: person.avatarBytes,
      ),
      title: Text(name, style: GoogleFonts.sourceSans3(color: albumInk)),
      subtitle: FamilyRoleChip(role: person.role),
      trailing: onRemove == null
          ? null
          : TextButton(
              key: Key('manage-family-remove-${person.userId}'),
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
    );
  }
}

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
import 'add_co_owner_dialog.dart';
import 'delete_family_dialog.dart';
import 'family_blur_dialog.dart';
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
    this.currentUserId,
  });

  final String familyId;
  final FamilyDirectoryGateway? directoryApi;
  final FamiliesGateway? familiesApi;
  final ManageFamiliesGateway? manageApi;
  final InviteGateway? inviteApi;
  final Future<void> Function()? onLogout;

  /// Signed-in user. Their own row never shows Make member or Remove.
  final String? currentUserId;

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  FamilyDetail? _detail;
  List<MemberFamily> _families = const [];
  List<StewardFamily> _stewarded = const [];
  String? _sessionFamilyId;
  var _loading = true;
  var _missing = false;
  final _name = TextEditingController();
  final _resendNotes = <String, String>{};
  String? _resendBusyId;

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
      final stewarded = widget.familiesApi == null
          ? const <StewardFamily>[]
          : await widget.familiesApi!.listStewarded();
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
        _stewarded = stewarded;
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
    final picked = await showAddCoOwnerDialog(
      context,
      familyName: detail.name,
      coOwnerCount: _coOwners.length,
      members: _members,
    );
    if (picked == null) return;
    try {
      await _manage.addCoOwner(familyId: detail.id, userId: picked);
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  bool _canActOn(FamilyPerson person) {
    if (person.role == 'owner') return false;
    final self = widget.currentUserId;
    if (self != null && person.userId == self) return false;
    return true;
  }

  String _personName(FamilyPerson person) {
    final name = person.displayName?.trim() ?? '';
    return name.isEmpty ? 'Member' : name;
  }

  Future<void> _makeMember(FamilyPerson person) async {
    final detail = _detail;
    if (detail == null || !_isOwner || !_canActOn(person)) return;
    final confirmed = await showFamilyBlurDialog(
      context,
      dialogKey: const Key('make-member-dialog'),
      title: 'Make ${_personName(person)} a member?',
      body: 'They keep their stories and access but lose co-owner powers.',
      confirmLabel: 'Make member',
      confirmKey: const Key('make-member-confirm'),
      confirmColor: albumTerracotta,
    );
    if (!confirmed || !mounted) return;
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
    final name = _personName(person);
    final confirmed = await showFamilyBlurDialog(
      context,
      dialogKey: const Key('remove-member-dialog'),
      title: 'Remove $name from ${detail.name}?',
      body:
          'They lose access to ${detail.name} and its branches. Their stories stay.',
      confirmLabel: 'Remove',
      confirmKey: const Key('remove-member-confirm'),
      confirmColor: _detailError,
    );
    if (!confirmed || !mounted) return;
    try {
      await _manage.removeMember(familyId: detail.id, userId: person.userId);
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _resendInvite(FamilyInvite invite) async {
    final email = invite.email?.trim() ?? '';
    if (email.isEmpty || _resendBusyId != null) return;
    setState(() => _resendBusyId = invite.id);
    try {
      await _manage.resendInvite(invite.id);
      if (!mounted) return;
      setState(() {
        _resendNotes[invite.id] =
            'Invite sent again to $email. The old link no longer works.';
      });
      await _load();
    } on ManageFamiliesException catch (e) {
      _snack(e.message);
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _resendBusyId = null);
    }
  }

  Future<void> _cancelInvite(FamilyInvite invite) async {
    final detail = _detail;
    if (detail == null || _resendBusyId != null) return;
    final email = invite.email?.trim() ?? '';
    final body = email.isEmpty
        ? "This invite link won't work for anyone anymore. You can make a new one any time."
        : "$email won't be able to join ${detail.name} with this link. You can invite them again any time.";
    final confirmed = await showFamilyBlurDialog(
      context,
      dialogKey: const Key('cancel-invite-dialog'),
      title: 'Cancel this invite?',
      body: body,
      confirmLabel: 'Cancel invite',
      confirmKey: const Key('cancel-invite-confirm'),
      confirmColor: _detailError,
      cancelLabel: 'Keep invite',
      cancelKey: const Key('cancel-invite-keep'),
    );
    if (!confirmed || !mounted) return;
    try {
      await _manage.revokeInvite(invite.id);
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
    if (!mounted) return;
    await _load();
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
        onInvite: _inviteSession,
        onLogout: widget.onLogout,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _missing || detail == null
          ? const Center(child: Text('Not found'))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          key: const Key('manage-family-back'),
                          onPressed: () => context.go(AppRoutes.manageFamilies),
                          style: TextButton.styleFrom(
                            foregroundColor: albumTerracotta,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text('Manage families', style: _label),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          detail.name,
                          style: GoogleFonts.newsreader(
                            color: albumInk,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage family settings, co-owners, members, and archival access permissions.',
                          style: _helper.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 32),
                        _DetailCard(
                          child: _split(
                            left: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('FAMILY NAME', style: _kicker),
                                const SizedBox(height: 6),
                                Text(
                                  'The primary display name for this shared family heritage archive.',
                                  style: _helper,
                                ),
                              ],
                            ),
                            right: Row(
                              children: [
                                SizedBox(
                                  width: 288,
                                  child: TextField(
                                    key: const Key('manage-family-name'),
                                    controller: _name,
                                    readOnly: !_canAdmin,
                                    style: GoogleFonts.literata(
                                      color: albumInk,
                                      fontSize: 16,
                                    ),
                                    decoration: _field,
                                  ),
                                ),
                                if (_canAdmin) ...[
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    key: const Key('manage-family-rename'),
                                    onPressed: _rename,
                                    style: _outlineButton,
                                    child: const Text('Rename'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _DetailCard(
                          child: _split(
                            left: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR ROLE', style: _kicker),
                                const SizedBox(height: 6),
                                Text(_roleHelp(detail.myRole), style: _helper),
                              ],
                            ),
                            right: _RolePill(role: detail.myRole),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _split(
                                left: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Co-owners (up to two)',
                                      style: _section,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Co-owners share full administrative privileges with the primary owner.',
                                      style: _helper,
                                    ),
                                  ],
                                ),
                                right: _canAdmin && _coOwners.length < 2
                                    ? OutlinedButton.icon(
                                        key: const Key(
                                          'manage-family-add-co-owner',
                                        ),
                                        onPressed: _members.isEmpty
                                            ? null
                                            : _addCoOwner,
                                        style: _quietButton,
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add co-owner'),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_coOwners.length} of 2',
                                key: const Key('manage-family-co-owner-count'),
                                style: _helper,
                              ),
                              const SizedBox(height: 16),
                              _PeopleList(
                                children: [
                                  for (final person in _coOwners)
                                    _PersonRow(
                                      person: person,
                                      onMakeMember:
                                          _isOwner && _canActOn(person)
                                          ? () => _makeMember(person)
                                          : null,
                                      onRemove: _isOwner && _canActOn(person)
                                          ? () => _removeMember(person)
                                          : null,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Co-owners have the same powers as the owner.',
                                style: _helper.copyWith(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  fontFamily:
                                      GoogleFonts.sourceSans3().fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _DetailCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _split(
                                left: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Members', style: _section),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Family members with access to read and contribute stories to the album.',
                                      style: _helper,
                                    ),
                                  ],
                                ),
                                right: FilledButton(
                                  key: const Key('manage-family-invite'),
                                  onPressed: _inviteThisFamily,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: albumTerracotta,
                                    foregroundColor: albumParchment,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: _label,
                                  ),
                                  child: const Text('Invite'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _PeopleList(
                                children: [
                                  for (final person in _roster)
                                    _PersonRow(
                                      person: person,
                                      trailing: person.role == 'owner'
                                          ? 'Primary'
                                          : person.role == 'co_owner'
                                          ? 'Co-owner'
                                          : null,
                                      onRemove:
                                          person.role == 'member' &&
                                              _canAdmin &&
                                              _canActOn(person)
                                          ? () => _removeMember(person)
                                          : null,
                                    ),
                                ],
                              ),
                              if (_canAdmin &&
                                  detail.pendingInvites.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Text(
                                      'PENDING INVITES',
                                      style: GoogleFonts.sourceSans3(
                                        color: _detailVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${detail.pendingInvites.length} waiting',
                                      key: const Key(
                                        'manage-family-pending-count',
                                      ),
                                      style: GoogleFonts.sourceSans3(
                                        color: _detailVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _PeopleList(
                                  children: [
                                    for (final invite in detail.pendingInvites)
                                      _PendingInviteRow(
                                        invite: invite,
                                        note: _resendNotes[invite.id],
                                        busy: _resendBusyId == invite.id,
                                        onResend:
                                            invite.email?.trim().isNotEmpty ==
                                                true
                                            ? () => _resendInvite(invite)
                                            : null,
                                        onCancel: () => _cancelInvite(invite),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Resend emails the invite again and gives it 7 more days. Cancel stops the link from working.',
                                  style: GoogleFonts.sourceSans3(
                                    color: _detailVariant,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_isOwner && _coOwners.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _DetailCard(
                            child: _split(
                              left: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ownership Transfer', style: _section),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Transfer primary ownership of ${detail.name} album and archive to another co-owner.',
                                    style: _helper,
                                  ),
                                ],
                              ),
                              right: OutlinedButton(
                                key: const Key('manage-family-transfer'),
                                onPressed: _transfer,
                                style: _outlineButton,
                                child: const Text('Transfer ownership…'),
                              ),
                            ),
                          ),
                        ],
                        if (_isOwner) ...[
                          const SizedBox(height: 24),
                          _DetailCard(
                            borderColor: _detailError.withValues(alpha: 0.4),
                            child: _split(
                              left: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Soft-delete this family',
                                    style: _section.copyWith(
                                      color: _detailError,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hidden for 60 days, then permanently removed. Owner only. Recover from Manage families.',
                                    style: _helper,
                                  ),
                                ],
                              ),
                              right: OutlinedButton(
                                key: const Key('manage-family-delete'),
                                onPressed: _delete,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _detailError,
                                  backgroundColor: _detailError.withValues(
                                    alpha: 0.1,
                                  ),
                                  side: BorderSide(
                                    color: _detailError.withValues(alpha: 0.3),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: _label,
                                ),
                                child: const Text('Delete family…'),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<FamilyPerson> get _roster {
    final people = [...?_detail?.people];
    int rank(String role) => switch (role) {
      'owner' => 0,
      'co_owner' => 1,
      _ => 2,
    };
    people.sort((a, b) => rank(a.role).compareTo(rank(b.role)));
    return people;
  }

  Widget _split({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: left),
            const SizedBox(width: 24),
            right,
          ],
        );
      },
    );
  }
}

const _detailError = Color(0xFF9F403D);
const _detailLine = Color(0xFFB9B0AD);
const _detailVariant = Color(0xFF655E5B);

TextStyle get _label => GoogleFonts.sourceSans3(
  color: albumInk,
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

TextStyle get _kicker => GoogleFonts.sourceSans3(
  color: _detailVariant,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
);

TextStyle get _helper =>
    GoogleFonts.literata(color: _detailVariant, fontSize: 14);

TextStyle get _section => GoogleFonts.newsreader(
  color: albumInk,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

InputDecoration get _field => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: const Color(0xFFFAF2F0),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: _detailLine.withValues(alpha: 0.4)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: _detailLine.withValues(alpha: 0.4)),
  ),
);

ButtonStyle get _outlineButton => OutlinedButton.styleFrom(
  foregroundColor: albumInk,
  side: BorderSide(color: _detailLine.withValues(alpha: 0.8)),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _label,
);

ButtonStyle get _quietButton => OutlinedButton.styleFrom(
  foregroundColor: albumInk,
  backgroundColor: const Color(0xFFF5ECE9),
  side: BorderSide(color: _detailLine.withValues(alpha: 0.3)),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _label,
);

String _roleHelp(String role) {
  return switch (role) {
    'owner' => 'Your permission level grants full administrative controls over the family archive.',
    'co_owner' => 'Co-owners have the same powers as the owner.',
    _ =>
      'Family members with access to read and contribute stories to the album.',
  };
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? _detailLine.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: albumInk.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(32), child: child),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5DED6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        familyRoleLabel(role),
        style: GoogleFonts.sourceSans3(
          color: const Color(0xFF5E4E48),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _detailLine.withValues(alpha: 0.2)),
          bottom: BorderSide(color: _detailLine.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: _detailLine.withValues(alpha: 0.2),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PendingInviteRow extends StatelessWidget {
  const _PendingInviteRow({
    required this.invite,
    required this.note,
    required this.busy,
    required this.onResend,
    required this.onCancel,
  });

  final FamilyInvite invite;
  final String? note;
  final bool busy;
  final VoidCallback? onResend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final email = invite.email?.trim() ?? '';
    final label = email.isEmpty ? 'Invite link' : email;
    final expired = invite.isExpired;
    final status = expired ? 'Expired' : 'Pending';
    return Padding(
      key: Key('manage-family-pending-${invite.id}'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _InviteMark(email: email),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.literata(
                    color: albumInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _inviteWhen(invite),
                  style: GoogleFonts.sourceSans3(
                    color: _detailVariant,
                    fontSize: 12,
                  ),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note!,
                      key: Key('manage-family-resend-note-${invite.id}'),
                      style: GoogleFonts.sourceSans3(
                        color: _detailVariant,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: expired
                  ? _detailError.withValues(alpha: 0.1)
                  : const Color(0xFFF5ECE9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: GoogleFonts.sourceSans3(
                color: expired ? _detailError : _detailVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onResend != null)
            busy
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      key: Key('manage-family-resend-busy-${invite.id}'),
                      width: 16,
                      height: 16,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    key: Key('manage-family-resend-${invite.id}'),
                    onPressed: onResend,
                    style: TextButton.styleFrom(foregroundColor: albumInk),
                    child: Text(
                      'Resend',
                      style: GoogleFonts.sourceSans3(
                        color: albumInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          TextButton(
            key: Key('manage-family-cancel-invite-${invite.id}'),
            onPressed: busy ? null : onCancel,
            style: TextButton.styleFrom(foregroundColor: _detailError),
            child: Text(
              'Cancel invite',
              style: GoogleFonts.sourceSans3(
                color: _detailError,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteMark extends StatelessWidget {
  const _InviteMark({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF5ECE9),
        shape: BoxShape.circle,
      ),
      child: email.isEmpty
          ? const Icon(Icons.link, size: 18, color: albumInk)
          : Text(
              _inviteInitials(email),
              style: GoogleFonts.newsreader(
                color: albumInk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

String _inviteInitials(String email) {
  final local = email.split('@').first;
  final parts = local
      .split(RegExp(r'[._+\-]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (local.length >= 2) return local.substring(0, 2).toUpperCase();
  return local.toUpperCase();
}

String _inviteWhen(FamilyInvite invite) {
  final sent = invite.sentAt;
  final expiry = invite.expiresAt;
  final verb = (invite.email?.trim().isNotEmpty ?? false) ? 'Sent' : 'Created';
  final sentLabel = sent == null ? '' : albumMonthDay(sent);
  if (expiry == null) return '$verb $sentLabel'.trim();
  final expWord = invite.isExpired ? 'Expired' : 'Expires';
  return '$verb $sentLabel · $expWord ${albumMonthDay(expiry)}'.trim();
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    this.onMakeMember,
    this.onRemove,
    this.trailing,
  });

  final FamilyPerson person;
  final VoidCallback? onMakeMember;
  final VoidCallback? onRemove;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final name = person.displayName?.trim().isNotEmpty == true
        ? person.displayName!.trim()
        : 'Member';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          ProfileAvatar(
            size: 40,
            displayName: person.displayName,
            bytes: person.avatarBytes,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.literata(
                    color: albumInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  familyRoleLabel(person.role),
                  style: GoogleFonts.sourceSans3(
                    color: _detailVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onMakeMember != null)
            TextButton(
              key: Key('manage-family-make-member-${person.userId}'),
              onPressed: onMakeMember,
              style: TextButton.styleFrom(foregroundColor: albumInk),
              child: Text(
                'Make member',
                style: GoogleFonts.sourceSans3(
                  color: albumInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (onRemove != null)
            TextButton(
              key: Key('manage-family-remove-${person.userId}'),
              onPressed: onRemove,
              style: TextButton.styleFrom(foregroundColor: _detailError),
              child: Text(
                'Remove',
                style: GoogleFonts.sourceSans3(
                  color: _detailError,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (onMakeMember == null && trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5ECE9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trailing!,
                style: GoogleFonts.sourceSans3(
                  color: _detailVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

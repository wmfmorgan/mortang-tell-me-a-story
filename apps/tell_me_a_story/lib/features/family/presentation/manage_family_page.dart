import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_invite.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/album/album_chrome.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';
import 'package:tell_me_a_story/core/widgets/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/features/family/presentation/add_co_owner_dialog.dart';
import 'package:tell_me_a_story/features/family/presentation/delete_family_dialog.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_providers.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_start_timeline.dart';
import 'package:tell_me_a_story/features/family/presentation/transfer_ownership_dialog.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal.dart';

part 'manage_family_cards.dart';
part 'manage_family_rows.dart';
part 'manage_family_style.dart';

/// Stitch detail `1c097b0e40cd4703a76fb8b1baf1ebc7`.
class ManageFamilyPage extends ConsumerStatefulWidget {
  const ManageFamilyPage({
    super.key,
    required this.familyId,
    this.onLogout,
    this.currentUserId,
  });

  final String familyId;
  final Future<void> Function()? onLogout;

  /// Signed-in user. Their own row never shows Make member or Remove.
  final String? currentUserId;

  @override
  ConsumerState<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends ConsumerState<ManageFamilyPage> {
  final _name = TextEditingController();
  late final UnsavedGuard _guard;
  ValueKey<String>? _pageKey;
  final _resendNotes = <String, String>{};
  String? _resendBusyId;

  /// Family picked in the header since the last load.
  String? _picked;

  ManageFamilyView? get _view =>
      ref.read(manageFamilyViewProvider(widget.familyId)).value;

  FamilyDetail? get _detail => _view?.detail;

  ManageFamiliesRepository get _manage =>
      ref.read(manageFamiliesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _guard = UnsavedGuard(
      exitPrompts: false,
      isDirty: _isDirty,
      save: _rename,
      discard: () {
        if (_detail case final detail?) _name.text = detail.name;
      },
    );
    ref.listenManual(
      manageFamilyViewProvider(widget.familyId),
      (_, next) => _syncName(next),
      fireImmediately: true,
    );
  }

  /// Each completed load resets the name field, as the page always has.
  void _syncName(AsyncValue<ManageFamilyView> next) {
    if (next case AsyncData(:final value)) {
      if (value.detail case final detail?) _name.text = detail.name;
    }
  }

  bool _isDirty() {
    final detail = _detail;
    return detail != null && _canAdmin(detail) && _name.text != detail.name;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final key = GoRouterState.of(context).pageKey;
    if (_pageKey == key) return;
    if (_pageKey case final previous?) {
      UnsavedGuards.unregister(previous, _guard);
    }
    _pageKey = key;
    UnsavedGuards.register(key, _guard);
  }

  @override
  void dispose() {
    if (_pageKey case final key?) UnsavedGuards.unregister(key, _guard);
    _guard.dispose();
    _name.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _picked = null);
    ref.invalidate(manageFamilyViewProvider(widget.familyId));
  }

  String? _sessionOf(ManageFamilyView? loaded, String? remembered) {
    if (_picked case final picked?) return picked;
    if (loaded == null) return null;
    return loaded.sessionFamilyId ?? remembered;
  }

  String? get _sessionFamilyId =>
      _sessionOf(_view, ref.read(familySelectionProvider));

  Future<void> _startTimeline() async {
    final view = _view;
    final id = _sessionFamilyId;
    if (id == null || !_isMember(view, id)) return;
    final userId =
        widget.currentUserId ?? ref.read(appSessionProvider).currentUserId;
    if (userId == null) return;
    await startManageTimeline(
      context,
      ref,
      familyId: id,
      familyName: _sessionName(view, id),
      userId: userId,
      onCreated: _reload,
    );
  }

  Future<bool> _rename() async {
    final detail = _detail;
    if (detail == null) return false;
    try {
      await _manage.renameFamily(familyId: detail.id, name: _name.text);
      _reload();
      return true;
    } on AppException catch (e) {
      _snack(e.message);
      return false;
    }
  }

  /// Runs [call], reloads on success, and shows the mapped message on failure.
  Future<void> _mutate(Future<void> Function() call) async {
    try {
      await call();
      _reload();
    } on AppException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _addCoOwner() async {
    final detail = _detail;
    if (detail == null) return;
    final coOwners = _coOwnersOf(detail);
    if (coOwners.length >= 2) return;
    final picked = await showAddCoOwnerDialog(
      context,
      familyName: detail.name,
      coOwnerCount: coOwners.length,
      members: _membersOf(detail),
    );
    if (picked == null) return;
    await _mutate(
      () => _manage.addCoOwner(familyId: detail.id, userId: picked),
    );
  }

  bool _canActOn(FamilyPerson person) {
    if (person.role == 'owner') return false;
    final self = widget.currentUserId;
    return self == null || person.userId != self;
  }

  Future<void> _makeMember(FamilyPerson person) async {
    final detail = _detail;
    if (detail == null || !_isOwner(detail) || !_canActOn(person)) return;
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
    await _mutate(
      () => _manage.removeCoOwner(familyId: detail.id, userId: person.userId),
    );
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
    await _mutate(
      () => _manage.removeMember(familyId: detail.id, userId: person.userId),
    );
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
      _reload();
    } on AppException catch (e) {
      _snack(e.message);
      _reload();
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
    await _mutate(() => _manage.revokeInvite(invite.id));
  }

  Future<void> _transfer() async {
    final detail = _detail;
    if (detail == null) return;
    final coOwners = _coOwnersOf(detail);
    if (coOwners.isEmpty) return;
    final choice = await showTransferOwnershipDialog(
      context,
      familyName: detail.name,
      coOwners: coOwners,
    );
    if (choice == null) return;
    await _mutate(
      () => _manage.transferOwnership(
        familyId: detail.id,
        newOwnerUserId: choice.newOwnerUserId,
        formerOwnerBecomes: choice.formerOwnerBecomes,
      ),
    );
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
      ref.read(familySelectionProvider.notifier).forget(detail.id);
      if (!mounted) return;
      context.go(AppRoutes.manageFamilies);
    } on AppException catch (e) {
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
    );
    _reload();
  }

  Future<void> _inviteSession() async {
    final id =
        _sessionFamilyId ??
        await ref.read(inviteRepositoryProvider).currentFamilyId();
    if (id == null || !mounted) return;
    await InviteModal.show(
      context,
      familyId: id,
      familyName: _sessionName(_view, id),
    );
  }

  void _select(String id) {
    ref.read(familySelectionProvider.notifier).remember(id);
    setState(() => _picked = id);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  _DetailActions get _actions => _DetailActions(
    name: _name,
    canActOn: _canActOn,
    rename: _rename,
    addCoOwner: _addCoOwner,
    makeMember: _makeMember,
    remove: _removeMember,
    inviteFamily: _inviteThisFamily,
    resend: _resendInvite,
    cancelInvite: _cancelInvite,
    resendNotes: _resendNotes,
    resendBusyId: _resendBusyId,
    transfer: _transfer,
    delete: _delete,
  );

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(manageFamilyViewProvider(widget.familyId));
    final loaded = viewState.value;
    final session = _sessionOf(loaded, ref.watch(familySelectionProvider));
    final member = _isMember(loaded, session);
    return UnsavedGuardScope(
      guard: _guard,
      child: Scaffold(
        key: const Key('manage-family-detail'),
        backgroundColor: albumParchment,
        appBar: AlbumHeader(
          page: AlbumHeaderPage.manageFamilies,
          familyName: _sessionName(loaded, session),
          families: loaded?.families ?? const [],
          currentFamilyId: session,
          onFamilySelected: _select,
          stewarded: loaded?.stewarded ?? const [],
          canWrite: member,
          onInvite: member ? _inviteSession : null,
          onStartTimeline: member ? _startTimeline : null,
          onLogout: widget.onLogout,
        ),
        body: viewState.when(
          skipError: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _NotFound(),
          data: (view) => switch (view.detail) {
            final detail? => _DetailList(detail: detail, actions: _actions),
            null => const _NotFound(),
          },
        ),
      ),
    );
  }
}

bool _isMember(ManageFamilyView? view, String? id) =>
    id != null && (view?.families.any((family) => family.id == id) ?? false);

String _sessionName(ManageFamilyView? view, String? id) {
  for (final family in view?.families ?? const <MemberFamily>[]) {
    if (family.id == id) return family.name;
  }
  return view?.detail?.name ?? 'Family';
}

bool _isOwner(FamilyDetail detail) => detail.myRole == 'owner';

bool _canAdmin(FamilyDetail detail) =>
    _isOwner(detail) || detail.myRole == 'co_owner';

List<FamilyPerson> _coOwnersOf(FamilyDetail detail) => [
  for (final person in detail.people)
    if (person.role == 'co_owner') person,
];

List<FamilyPerson> _membersOf(FamilyDetail detail) => [
  for (final person in detail.people)
    if (person.role == 'member') person,
];

/// Owner first, then co-owners, then members.
List<FamilyPerson> _rosterOf(FamilyDetail detail) {
  final people = [...detail.people];
  int rank(String role) => switch (role) {
    'owner' => 0,
    'co_owner' => 1,
    _ => 2,
  };
  people.sort((a, b) => rank(a.role).compareTo(rank(b.role)));
  return people;
}

String _personName(FamilyPerson person) {
  final name = person.displayName?.trim() ?? '';
  return name.isEmpty ? 'Member' : name;
}

/// What the detail cards can do, wired to the page state.
class _DetailActions {
  const _DetailActions({
    required this.name,
    required this.canActOn,
    required this.rename,
    required this.addCoOwner,
    required this.makeMember,
    required this.remove,
    required this.inviteFamily,
    required this.resend,
    required this.cancelInvite,
    required this.resendNotes,
    required this.resendBusyId,
    required this.transfer,
    required this.delete,
  });

  final TextEditingController name;
  final bool Function(FamilyPerson person) canActOn;
  final VoidCallback rename;
  final VoidCallback addCoOwner;
  final ValueChanged<FamilyPerson> makeMember;
  final ValueChanged<FamilyPerson> remove;
  final VoidCallback inviteFamily;
  final ValueChanged<FamilyInvite> resend;
  final ValueChanged<FamilyInvite> cancelInvite;
  final Map<String, String> resendNotes;
  final String? resendBusyId;
  final VoidCallback transfer;
  final VoidCallback delete;
}

part of 'manage_family_page.dart';

class _DetailList extends StatelessWidget {
  const _DetailList({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: _DetailSections(detail: detail, actions: actions),
          ),
        ),
      ],
    );
  }
}

class _DetailSections extends StatelessWidget {
  const _DetailSections({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final owner = _isOwner(detail);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailIntro(name: detail.name),
        const SizedBox(height: 32),
        _NameCard(detail: detail, actions: actions),
        const SizedBox(height: 24),
        _RoleCard(role: detail.myRole),
        const SizedBox(height: 24),
        _CoOwnersCard(detail: detail, actions: actions),
        const SizedBox(height: 24),
        _MembersCard(detail: detail, actions: actions),
        if (owner && _coOwnersOf(detail).isNotEmpty) ...[
          const SizedBox(height: 24),
          _TransferCard(familyName: detail.name, onTransfer: actions.transfer),
        ],
        if (owner) ...[
          const SizedBox(height: 24),
          _DeleteCard(onDelete: actions.delete),
        ],
        const SizedBox(height: 64),
      ],
    );
  }
}

class _DetailIntro extends StatelessWidget {
  const _DetailIntro({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          name,
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
      ],
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final canAdmin = _canAdmin(detail);
    return _DetailCard(
      child: _Split(
        left: _CardLead(
          title: 'FAMILY NAME',
          titleStyle: _kicker,
          helper: 'The primary display name for this shared family heritage archive.',
        ),
        right: Row(
          children: [
            SizedBox(
              width: 288,
              child: TextField(
                key: const Key('manage-family-name'),
                controller: actions.name,
                readOnly: !canAdmin,
                style: GoogleFonts.literata(color: albumInk, fontSize: 16),
                decoration: _field,
              ),
            ),
            if (canAdmin) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                key: const Key('manage-family-rename'),
                onPressed: actions.rename,
                style: _outlineButton,
                child: const Text('Rename'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: _Split(
        left: _CardLead(
          title: 'YOUR ROLE',
          titleStyle: _kicker,
          helper: _roleHelp(role),
        ),
        right: _RolePill(role: role),
      ),
    );
  }
}

class _CoOwnersCard extends StatelessWidget {
  const _CoOwnersCard({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final coOwners = _coOwnersOf(detail);
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Split(
            left: _CardLead(
              title: 'Co-owners (up to two)',
              titleStyle: _section,
              helper: 'Co-owners share full administrative privileges with the primary owner.',
              gap: 4,
            ),
            right: _canAdmin(detail) && coOwners.length < 2
                ? _AddCoOwnerButton(
                    onPressed: _membersOf(detail).isEmpty
                        ? null
                        : actions.addCoOwner,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Text(
            '${coOwners.length} of 2',
            key: const Key('manage-family-co-owner-count'),
            style: _helper,
          ),
          const SizedBox(height: 16),
          _CoOwnerList(detail: detail, actions: actions),
          const SizedBox(height: 16),
          Text(
            'Co-owners have the same powers as the owner.',
            style: _helper.copyWith(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              fontFamily: GoogleFonts.sourceSans3().fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoOwnerList extends StatelessWidget {
  const _CoOwnerList({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final owner = _isOwner(detail);
    return _PeopleList(
      children: [
        for (final person in _coOwnersOf(detail))
          _PersonRow(
            person: person,
            onMakeMember: owner && actions.canActOn(person)
                ? () => actions.makeMember(person)
                : null,
            onRemove: owner && actions.canActOn(person)
                ? () => actions.remove(person)
                : null,
          ),
      ],
    );
  }
}

class _AddCoOwnerButton extends StatelessWidget {
  const _AddCoOwnerButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('manage-family-add-co-owner'),
      onPressed: onPressed,
      style: _quietButton,
      child: const PlusLabel(label: 'Add co-owner'),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final canAdmin = _canAdmin(detail);
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Split(
            left: _CardLead(
              title: 'Members',
              titleStyle: _section,
              helper: 'Family members with access to read and contribute stories to the album.',
              gap: 4,
            ),
            right: _InviteButton(onPressed: actions.inviteFamily),
          ),
          const SizedBox(height: 16),
          _RosterList(detail: detail, actions: actions),
          if (canAdmin && detail.pendingInvites.isNotEmpty)
            _PendingInvites(detail: detail, actions: actions),
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final canAdmin = _canAdmin(detail);
    return _PeopleList(
      children: [
        for (final person in _rosterOf(detail))
          _PersonRow(
            person: person,
            trailing: switch (person.role) {
              'owner' => 'Primary',
              'co_owner' => 'Co-owner',
              _ => null,
            },
            onRemove:
                person.role == 'member' && canAdmin && actions.canActOn(person)
                ? () => actions.remove(person)
                : null,
          ),
      ],
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('manage-family-invite'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: _label,
      ),
      child: const Text('Invite'),
    );
  }
}

class _PendingInvites extends StatelessWidget {
  const _PendingInvites({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    final small = GoogleFonts.sourceSans3(color: _detailVariant, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'PENDING INVITES',
              style: small.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              '${detail.pendingInvites.length} waiting',
              key: const Key('manage-family-pending-count'),
              style: small,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PendingInviteList(detail: detail, actions: actions),
        const SizedBox(height: 12),
        Text(
          'Resend emails the invite again and gives it 7 more days. Cancel stops the link from working.',
          style: small.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _PendingInviteList extends StatelessWidget {
  const _PendingInviteList({required this.detail, required this.actions});

  final FamilyDetail detail;
  final _DetailActions actions;

  @override
  Widget build(BuildContext context) {
    return _PeopleList(
      children: [
        for (final invite in detail.pendingInvites)
          _PendingInviteRow(
            invite: invite,
            note: actions.resendNotes[invite.id],
            busy: actions.resendBusyId == invite.id,
            onResend: invite.email?.trim().isNotEmpty == true
                ? () => actions.resend(invite)
                : null,
            onCancel: () => actions.cancelInvite(invite),
          ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.familyName, required this.onTransfer});

  final String familyName;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: _Split(
        left: _CardLead(
          title: 'Ownership Transfer',
          titleStyle: _section,
          helper:
              'Transfer primary ownership of $familyName album and archive to another co-owner.',
        ),
        right: OutlinedButton(
          key: const Key('manage-family-transfer'),
          onPressed: onTransfer,
          style: _outlineButton,
          child: const Text('Transfer ownership…'),
        ),
      ),
    );
  }
}

class _DeleteCard extends StatelessWidget {
  const _DeleteCard({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      borderColor: _detailError.withValues(alpha: 0.4),
      child: _Split(
        left: _CardLead(
          title: 'Soft-delete this family',
          titleStyle: _section.copyWith(color: _detailError),
          helper: 'Hidden for 60 days, then permanently removed. Owner only. Recover from Manage families.',
        ),
        right: OutlinedButton(
          key: const Key('manage-family-delete'),
          onPressed: onDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: _detailError,
            backgroundColor: _detailError.withValues(alpha: 0.1),
            side: BorderSide(color: _detailError.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: _label,
          ),
          child: const Text('Delete family…'),
        ),
      ),
    );
  }
}

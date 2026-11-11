part of 'manage_family_page.dart';

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
    final expired = invite.isExpired;
    return Padding(
      key: Key('manage-family-pending-${invite.id}'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _InviteMark(email: email),
          const SizedBox(width: 14),
          Expanded(
            child: _InviteText(invite: invite, email: email, note: note),
          ),
          _Chip(
            label: expired ? 'Expired' : 'Pending',
            color: expired ? _detailError.withValues(alpha: 0.1) : null,
            textColor: expired ? _detailError : null,
          ),
          if (onResend case final resend?)
            busy
                ? _ResendBusy(inviteId: invite.id)
                : _RowAction(
                    buttonKey: Key('manage-family-resend-${invite.id}'),
                    label: 'Resend',
                    onPressed: resend,
                  ),
          _RowAction(
            buttonKey: Key('manage-family-cancel-invite-${invite.id}'),
            label: 'Cancel invite',
            onPressed: busy ? null : onCancel,
            color: _detailError,
          ),
        ],
      ),
    );
  }
}

class _InviteText extends StatelessWidget {
  const _InviteText({
    required this.invite,
    required this.email,
    required this.note,
  });

  final FamilyInvite invite;
  final String email;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          email.isEmpty ? 'Invite link' : email,
          style: GoogleFonts.literata(
            color: albumInk,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          _inviteWhen(invite),
          style: GoogleFonts.sourceSans3(color: _detailVariant, fontSize: 12),
        ),
        if (note case final note?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note,
              key: Key('manage-family-resend-note-${invite.id}'),
              style: GoogleFonts.sourceSans3(
                color: _detailVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResendBusy extends StatelessWidget {
  const _ResendBusy({required this.inviteId});

  final String inviteId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        key: Key('manage-family-resend-busy-$inviteId'),
        width: 16,
        height: 16,
        child: const CircularProgressIndicator(strokeWidth: 2),
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
          Expanded(child: _PersonText(person: person)),
          if (onMakeMember case final makeMember?)
            _RowAction(
              buttonKey: Key('manage-family-make-member-${person.userId}'),
              label: 'Make member',
              onPressed: makeMember,
            ),
          if (onRemove case final remove?)
            _RowAction(
              buttonKey: Key('manage-family-remove-${person.userId}'),
              label: 'Remove',
              onPressed: remove,
              color: _detailError,
            )
          else if (trailing case final label? when onMakeMember == null)
            _Chip(label: label),
        ],
      ),
    );
  }
}

class _PersonText extends StatelessWidget {
  const _PersonText({required this.person});

  final FamilyPerson person;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _personName(person),
          style: GoogleFonts.literata(
            color: albumInk,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          familyRoleLabel(person.role),
          style: GoogleFonts.sourceSans3(color: _detailVariant, fontSize: 12),
        ),
      ],
    );
  }
}

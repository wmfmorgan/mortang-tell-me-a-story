import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/create_invite_result.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/features/invites/presentation/invite_modal_providers.dart';

const _sendFailed = 'Couldn’t send invite. Try again.';

/// Invite dialog matching the Stitch Email, Link, and SMS screens.
/// SMS is visual only until a later milestone.
class InviteModal extends ConsumerStatefulWidget {
  const InviteModal({
    super.key,
    required this.familyId,
    this.familyName = 'Family',
  });

  final String familyId;
  final String familyName;

  static Future<void> show(
    BuildContext context, {
    required String familyId,
    String familyName = 'Family',
  }) {
    return showBlurredCard<void>(
      context: context,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 512,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
        ),
        child: Material(
          color: albumParchment,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: albumSage),
          ),
          child: InviteModal(familyId: familyId, familyName: familyName),
        ),
      ),
    );
  }

  @override
  ConsumerState<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends ConsumerState<InviteModal> {
  final _emailController = TextEditingController();
  final _emailNoteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsNoteController = TextEditingController();
  final _linkController = TextEditingController();
  var _tab = 0;
  var _busy = false;
  String? _linkUrl;
  String? _pickedPersonId;
  final _emailDrafts = <String, TextEditingController>{};
  final _addingEmail = <String>{};
  final _rowError = <String, String>{};
  final _pendingSend = <String, CreateInviteResult>{};
  String? _rowBusyId;

  InviteRepository get _invites => ref.read(inviteRepositoryProvider);

  NotInvitedPeople get _notInvited =>
      ref.read(notInvitedPeopleProvider(widget.familyId).notifier);

  @override
  void dispose() {
    _emailController.dispose();
    _emailNoteController.dispose();
    _phoneController.dispose();
    _smsNoteController.dispose();
    _linkController.dispose();
    for (final draft in _emailDrafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (index == 2) {
      ref.invalidate(inviteLinkPeopleProvider(widget.familyId));
    }
  }

  void _dropNotInvited(String personId) {
    _emailDrafts.remove(personId)?.dispose();
    _addingEmail.remove(personId);
    _rowError.remove(personId);
    _pendingSend.remove(personId);
    _notInvited.drop(personId);
  }

  Future<void> _inviteNotInvited(Person person) async {
    final email = person.email?.trim() ?? '';
    if (_rowBusyId != null || email.isEmpty) return;
    setState(() {
      _rowBusyId = person.id;
      _rowError.remove(person.id);
    });
    await _sendToRow(person, email);
  }

  /// Creates and sends [person]'s invite, showing any failure on the row.
  Future<void> _sendToRow(Person person, String email) async {
    try {
      await _createAndSend(person, email);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _rowError[person.id] = error.message);
    } catch (_) {
      // Boundary: unexpected failures show the generic row copy.
      if (!mounted) return;
      setState(() => _rowError[person.id] = _sendFailed);
    } finally {
      if (mounted) setState(() => _rowBusyId = null);
    }
  }

  /// Creates the invite once, then sends it. A second tap after a failed
  /// send retries the email and does not create another invite.
  Future<void> _createAndSend(Person person, String email) async {
    final invites = _invites;
    final created = _pendingSend[person.id] ??= await invites.createInvite(
      familyId: widget.familyId,
      personId: person.id,
      email: email,
    );
    await invites.sendInviteEmail(
      inviteId: created.inviteId,
      token: created.token,
    );
    _pendingSend.remove(person.id);
    if (!mounted) return;
    setState(() => _dropNotInvited(person.id));
  }

  Future<void> _saveEmailAndInvite(Person person) async {
    final draft = _emailDrafts[person.id]?.text.trim() ?? '';
    if (draft.isEmpty || _rowBusyId != null) return;
    setState(() {
      _rowBusyId = person.id;
      _rowError.remove(person.id);
    });
    final saved = await _saveEmail(person, draft);
    if (saved == null || !mounted) return;
    _notInvited.replace(saved);
    setState(() => _addingEmail.remove(person.id));
    final email = saved.email?.trim() ?? '';
    if (email.isEmpty) {
      setState(() => _rowBusyId = null);
      return;
    }
    await _sendToRow(saved, email);
  }

  /// Writes [email] on [person]; null after a failure shown on the row.
  Future<Person?> _saveEmail(Person person, String email) async {
    try {
      return await ref
          .read(peopleRepositoryProvider)
          .updatePerson(
            personId: person.id,
            name: person.name,
            email: email,
            writeEmail: true,
          );
    } catch (error) {
      // Boundary: mapped copy, or the generic retry prompt.
      if (mounted) {
        setState(() {
          _rowBusyId = null;
          _rowError[person.id] = appErrorMessage(error) ?? 'Try again';
        });
      }
      return null;
    }
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _toast(_sendFailed);
      return;
    }
    setState(() => _busy = true);
    try {
      // The personal note is on the screen only. send-invite-email has no note.
      final invites = _invites;
      final created = await invites.createInvite(
        familyId: widget.familyId,
        email: email,
      );
      await invites.sendInviteEmail(
        inviteId: created.inviteId,
        token: created.token,
      );
      if (!mounted) return;
      _toast('Invite sent');
      Navigator.of(context).pop();
    } catch (_) {
      // Boundary: every failure shows the send-failed toast.
      if (!mounted) return;
      _toast(_sendFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createLink({String? personId}) async {
    setState(() {
      _busy = true;
      _pickedPersonId = personId;
    });
    try {
      final created = await _invites.createInvite(
        familyId: widget.familyId,
        personId: personId,
      );
      if (!mounted) return;
      setState(() {
        _linkUrl = created.inviteUrl;
        _linkController.text = created.inviteUrl;
      });
    } catch (_) {
      // Boundary: every failure shows the send-failed toast.
      if (!mounted) return;
      _toast(_sendFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    final url = _linkUrl;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _toast('Link copied');
  }

  void _startAddEmail(String personId) {
    _emailDrafts.putIfAbsent(personId, TextEditingController.new);
    setState(() => _addingEmail.add(personId));
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final notInvited = _listOf(
      ref.watch(notInvitedPeopleProvider(widget.familyId)),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        28,
        28,
        28,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            familyName: widget.familyName,
            onClose: _busy ? null : _close,
          ),
          const SizedBox(height: 20),
          _Tabs(tab: _tab, onSelect: _busy ? null : _selectTab),
          const SizedBox(height: 20),
          _TabBody(state: this),
          if (notInvited.isNotEmpty) ...[
            const SizedBox(height: 20),
            _NotInvitedSection(state: this, people: notInvited),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: albumInk),
          const SizedBox(height: 16),
          _Actions(state: this),
          const SizedBox(height: 12),
          Text(
            _footnote(_tab),
            textAlign: TextAlign.center,
            style: _InviteType.footnote,
          ),
        ],
      ),
    );
  }
}

/// Rows of [people]; a failed load shows none, a reload keeps the last rows.
List<Person> _listOf(AsyncValue<List<Person>> people) =>
    people.hasError ? const [] : people.value ?? const [];

String _footnote(int tab) => switch (tab) {
  1 => 'We’ll send a short SMS with a secure join link.',
  2 => 'Share via Messages, Mail, or anywhere — no email required.',
  _ => 'Text uses phone number · Link creates a shareable invite URL anyone can open.',
};

class _Header extends StatelessWidget {
  const _Header({required this.familyName, required this.onClose});

  final String familyName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite to the family archive', style: _InviteType.title),
              const SizedBox(height: 4),
              _FamilyLine(familyName: familyName),
            ],
          ),
        ),
        IconButton(
          key: const Key('invite-close'),
          onPressed: onClose,
          style: IconButton.styleFrom(
            backgroundColor: albumParchment,
            foregroundColor: albumInk,
            fixedSize: const Size(32, 32),
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}

class _FamilyLine extends StatelessWidget {
  const _FamilyLine({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('Any member can invite', style: _InviteType.meta),
        Container(
          key: const Key('invite-family'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: albumSage,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(familyName, style: _InviteType.chip),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.onSelect});

  final int tab;
  final void Function(int index)? onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: albumSage),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (index, label, keyName) in const [
              (0, 'Email', 'invite-tab-email'),
              (1, 'Text (SMS)', 'invite-tab-sms'),
              (2, 'Link', 'invite-tab-link'),
            ])
              _TabButton(
                label: label,
                keyName: keyName,
                selected: tab == index,
                onTap: switch (onSelect) {
                  final select? => () => select(index),
                  null => null,
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.keyName,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String keyName;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? albumTerracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: Key(keyName),
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: _InviteType.tab(selected),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Watches the Link tab's people from the start so the picks are ready
/// when that tab opens.
class _TabBody extends ConsumerWidget {
  const _TabBody({required this.state});

  final _InviteModalState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    final linkPeople = _listOf(
      ref.watch(inviteLinkPeopleProvider(s.widget.familyId)),
    );
    return switch (s._tab) {
      1 => _SmsBody(
        phone: s._phoneController,
        note: s._smsNoteController,
        busy: s._busy,
      ),
      2 => _LinkBody(state: s, people: linkPeople),
      _ => _EmailBody(
        email: s._emailController,
        note: s._emailNoteController,
        busy: s._busy,
      ),
    };
  }
}

class _EmailBody extends StatelessWidget {
  const _EmailBody({
    required this.email,
    required this.note,
    required this.busy,
  });

  final TextEditingController email;
  final TextEditingController note;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Email address'),
        const SizedBox(height: 6),
        _Field(
          fieldKey: const Key('invite-email'),
          controller: email,
          hint: 'name@example.com',
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        const _NoteLabel(),
        const SizedBox(height: 6),
        _NoteField(
          fieldKey: const Key('invite-note'),
          controller: note,
          enabled: !busy,
        ),
        const SizedBox(height: 16),
        Text('They’ll join as a family member', style: _InviteType.meta),
      ],
    );
  }
}

class _SmsBody extends StatelessWidget {
  const _SmsBody({required this.phone, required this.note, required this.busy});

  final TextEditingController phone;
  final TextEditingController note;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Phone number'),
        const SizedBox(height: 6),
        _PhoneField(controller: phone, enabled: !busy),
        const SizedBox(height: 16),
        const _NoteLabel(),
        const SizedBox(height: 6),
        _NoteField(
          fieldKey: const Key('invite-sms-note'),
          controller: note,
          enabled: !busy,
        ),
        const SizedBox(height: 16),
        Text('They’ll join as a family member', style: _InviteType.meta),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: albumSage),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: albumParchment,
              border: Border(right: BorderSide(color: albumSage)),
            ),
            child: Text('+1', style: _InviteType.field),
          ),
          Expanded(
            child: TextField(
              key: const Key('invite-phone'),
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              style: _InviteType.field,
              decoration: InputDecoration(
                isDense: true,
                hintText: '(555) 000-0000',
                hintStyle: _InviteType.hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkBody extends StatelessWidget {
  const _LinkBody({required this.state, required this.people});

  final _InviteModalState state;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final busy = s._busy;
    final unlinked = people;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Who is this link for?'),
        const SizedBox(height: 8),
        _LinkPicks(
          people: unlinked,
          pickedPersonId: s._pickedPersonId,
          newPicked: s._linkUrl != null && s._pickedPersonId == null,
          onPick: busy ? null : (personId) => s._createLink(personId: personId),
        ),
        const SizedBox(height: 16),
        const _Label('Shareable invite link'),
        const SizedBox(height: 6),
        _LinkRow(
          controller: s._linkController,
          busy: busy,
          onCopy: s._copyLink,
        ),
        const SizedBox(height: 10),
        _LinkMeta(
          onGenerate: busy
              ? null
              : () => s._createLink(personId: s._pickedPersonId),
        ),
        const SizedBox(height: 8),
        Text(
          'Anyone with the link can request to join; a verified family member still confirms.',
          style: _InviteType.meta,
        ),
      ],
    );
  }
}

class _LinkPicks extends StatelessWidget {
  const _LinkPicks({
    required this.people,
    required this.pickedPersonId,
    required this.newPicked,
    required this.onPick,
  });

  final List<Person> people;
  final String? pickedPersonId;
  final bool newPicked;

  /// Creates a link for that person id, or for someone new when null.
  final void Function(String? personId)? onPick;

  @override
  Widget build(BuildContext context) {
    final pick = onPick;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final person in people)
          ChoiceChip(
            key: Key('invite-person-${person.id}'),
            label: Text(person.name),
            selected: pickedPersonId == person.id,
            onSelected: pick == null ? null : (_) => pick(person.id),
          ),
        ChoiceChip(
          key: const Key('invite-person-new'),
          label: const Text('Someone new'),
          selected: newPicked,
          onSelected: pick == null ? null : (_) => pick(null),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.controller,
    required this.busy,
    required this.onCopy,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('invite-link'),
            readOnly: true,
            controller: controller,
            style: _InviteType.mono,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: albumParchment,
              hintText: busy ? 'Creating link…' : '',
              hintStyle: _InviteType.hint,
              border: _fieldBorder,
              enabledBorder: _fieldBorder,
              focusedBorder: _fieldBorder,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('invite-copy'),
          onPressed: busy ? null : onCopy,
          style: _primaryStyle,
          child: const Text('Copy link'),
        ),
      ],
    );
  }
}

class _LinkMeta extends StatelessWidget {
  const _LinkMeta({required this.onGenerate});

  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          'Link expires in 7 days · Anyone can request to join',
          style: _InviteType.meta,
        ),
        TextButton.icon(
          key: const Key('invite-generate'),
          onPressed: onGenerate,
          style: TextButton.styleFrom(
            foregroundColor: albumTerracotta,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.refresh, size: 14),
          label: Text('Generate new link', style: _InviteType.linkAction),
        ),
      ],
    );
  }
}

class _NotInvitedSection extends StatelessWidget {
  const _NotInvitedSection({required this.state, required this.people});

  final _InviteModalState state;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('not-invited'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Not invited yet',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final person in people)
          _NotInvitedRow(state: state, person: person),
      ],
    );
  }
}

class _NotInvitedRow extends StatelessWidget {
  const _NotInvitedRow({required this.state, required this.person});

  final _InviteModalState state;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final busy = s._rowBusyId == person.id;
    final error = s._rowError[person.id];
    final draft = s._addingEmail.contains(person.id)
        ? s._emailDrafts[person.id]
        : null;
    return Padding(
      key: Key('not-invited-row-${person.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotInvitedSummary(
            person: person,
            adding: draft != null,
            onInvite: busy ? null : () => s._inviteNotInvited(person),
            onAddEmail: busy ? null : () => s._startAddEmail(person.id),
          ),
          if (draft != null) ...[
            const SizedBox(height: 8),
            _AddEmailRow(
              personId: person.id,
              draft: draft,
              enabled: !s._busy,
              onSave: busy ? null : () => s._saveEmailAndInvite(person),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              key: Key('not-invited-error-${person.id}'),
              style: _InviteType.meta.copyWith(color: albumTerracotta),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotInvitedSummary extends StatelessWidget {
  const _NotInvitedSummary({
    required this.person,
    required this.adding,
    required this.onInvite,
    required this.onAddEmail,
  });

  final Person person;
  final bool adding;
  final VoidCallback? onInvite;
  final VoidCallback? onAddEmail;

  @override
  Widget build(BuildContext context) {
    final email = person.email?.trim() ?? '';
    return Row(
      children: [
        ProfileAvatar(size: 32, displayName: person.name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name, style: _InviteType.field),
              if (!adding)
                Text(
                  email.isNotEmpty ? email : 'No email yet',
                  style: _InviteType.meta,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (email.isNotEmpty)
          OutlinedButton(
            key: Key('not-invited-invite-${person.id}'),
            onPressed: onInvite,
            style: _smallOutline,
            child: const Text('Invite'),
          )
        else if (!adding)
          OutlinedButton(
            key: Key('not-invited-add-${person.id}'),
            onPressed: onAddEmail,
            style: _smallOutline,
            child: const Text('Add email'),
          ),
      ],
    );
  }
}

class _AddEmailRow extends StatelessWidget {
  const _AddEmailRow({
    required this.personId,
    required this.draft,
    required this.enabled,
    required this.onSave,
  });

  final String personId;
  final TextEditingController draft;
  final bool enabled;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Field(
            fieldKey: Key('not-invited-email-$personId'),
            controller: draft,
            hint: 'name@example.com',
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          key: Key('not-invited-save-$personId'),
          onPressed: onSave,
          style: _smallOutline,
          child: const Text('Save and invite'),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final _InviteModalState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final busy = s._busy;
    final tab = s._tab;
    final (String idle, String keyName, VoidCallback onPrimary) = switch (tab) {
      1 => (
        'Send text invite',
        'invite-sms-send',
        () => s._toast('Text invites are not available yet.'),
      ),
      2 => ('Done', 'invite-done', s._close),
      _ => ('Send invite', 'invite-send', s._sendEmail),
    };
    final label = !busy || tab == 1
        ? idle
        : (tab == 0 ? 'Sending…' : 'Working…');
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          key: const Key('invite-cancel'),
          onPressed: busy ? null : s._close,
          style: _cancelStyle,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          key: Key(keyName),
          onPressed: busy ? null : onPrimary,
          style: _primaryStyle,
          child: Text(label),
        ),
      ],
    );
  }
}

final _cancelStyle = OutlinedButton.styleFrom(
  foregroundColor: albumInk,
  side: const BorderSide(color: albumSage),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _InviteType.button,
);

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _InviteType.label);
  }
}

class _NoteLabel extends StatelessWidget {
  const _NoteLabel();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Personal note ',
        style: _InviteType.label,
        children: [TextSpan(text: '(Optional)', style: _InviteType.optional)],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.enabled,
    this.keyboardType,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: _InviteType.field,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: _InviteType.hint,
        filled: true,
        fillColor: albumParchment,
        border: _fieldBorder,
        enabledBorder: _fieldBorder,
        focusedBorder: _fieldBorder.copyWith(
          borderSide: const BorderSide(color: albumTerracotta),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.fieldKey,
    required this.controller,
    required this.enabled,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      minLines: 3,
      maxLines: 3,
      style: _InviteType.field,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Add a warm note for your family member...',
        hintStyle: _InviteType.hint,
        filled: true,
        fillColor: albumParchment,
        alignLabelWithHint: true,
        border: _fieldBorder,
        enabledBorder: _fieldBorder,
        focusedBorder: _fieldBorder.copyWith(
          borderSide: const BorderSide(color: albumTerracotta),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: albumSage),
);

final _smallOutline = OutlinedButton.styleFrom(
  foregroundColor: albumInk,
  side: const BorderSide(color: albumSage),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _InviteType.button,
);

final _primaryStyle = FilledButton.styleFrom(
  backgroundColor: albumTerracotta,
  foregroundColor: albumParchment,
  disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.4),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _InviteType.buttonBold,
);

abstract final class _InviteType {
  static final title = GoogleFonts.newsreader(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: albumInk,
    height: 1.2,
  );
  static final label = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: albumInk,
  );
  static final optional = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: albumInk,
  );
  static final meta = GoogleFonts.sourceSans3(fontSize: 12, color: albumInk);
  static final chip = GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: albumInk,
  );
  static final field = GoogleFonts.sourceSans3(fontSize: 14, color: albumInk);
  static final hint = GoogleFonts.sourceSans3(
    fontSize: 14,
    color: albumInk.withValues(alpha: 0.7),
  );
  static final mono = GoogleFonts.sourceSans3(fontSize: 14, color: albumInk);
  static final button = GoogleFonts.sourceSans3(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  static final buttonBold = GoogleFonts.sourceSans3(
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );
  static final linkAction = GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: albumTerracotta,
  );
  static final footnote = GoogleFonts.sourceSans3(
    fontSize: 11,
    color: albumInk,
  );

  static TextStyle tab(bool selected) {
    return GoogleFonts.sourceSans3(
      fontSize: 12,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: selected ? albumParchment : albumInk,
    );
  }
}

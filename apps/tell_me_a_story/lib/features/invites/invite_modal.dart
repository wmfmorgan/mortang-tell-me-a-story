import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_avatar.dart';
import '../../data/invite_api.dart';
import '../../data/people_api.dart';
import '../family/family_blur_dialog.dart';

/// Invite dialog matching the Stitch Email, Link, and SMS screens.
/// SMS is visual only until a later milestone.
class InviteModal extends StatefulWidget {
  const InviteModal({
    super.key,
    required this.familyId,
    this.familyName = 'Family',
    this.api,
    this.people,
  });

  final String familyId;
  final String familyName;
  final InviteGateway? api;
  final PeopleGateway? people;

  static Future<void> show(
    BuildContext context, {
    required String familyId,
    String familyName = 'Family',
    InviteGateway? api,
    PeopleGateway? people,
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
          child: InviteModal(
            familyId: familyId,
            familyName: familyName,
            api: api,
            people: people,
          ),
        ),
      ),
    );
  }

  @override
  State<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends State<InviteModal> {
  final _emailController = TextEditingController();
  final _emailNoteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsNoteController = TextEditingController();
  final _linkController = TextEditingController();
  late final InviteGateway _api;
  PeopleGateway? _people;
  var _tab = 0;
  var _busy = false;
  String? _linkUrl;
  List<Person> _unlinked = const [];
  String? _pickedPersonId;
  List<Person> _notInvited = const [];
  final _emailDrafts = <String, TextEditingController>{};
  final _addingEmail = <String>{};
  final _rowError = <String, String>{};
  final _pendingSend = <String, String>{};
  String? _rowBusyId;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InviteApi();
    _people = widget.people;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotInvited());
  }

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
      _loadUnlinked();
    }
  }

  Future<void> _loadUnlinked() async {
    final people = _people;
    if (people == null) return;
    try {
      final rows = await people.listUnlinkedPeople(widget.familyId);
      if (!mounted) return;
      setState(() => _unlinked = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unlinked = const []);
    }
  }

  Future<void> _loadNotInvited() async {
    final people = widget.people;
    if (people == null) return;
    try {
      final rows = await people.listUnlinkedPeople(widget.familyId);
      if (!mounted) return;
      setState(() => _notInvited = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notInvited = const []);
    }
  }

  bool _hasEmail(Person person) => (person.email ?? '').trim().isNotEmpty;

  void _dropNotInvited(String personId) {
    _emailDrafts.remove(personId)?.dispose();
    _addingEmail.remove(personId);
    _rowError.remove(personId);
    _pendingSend.remove(personId);
    _notInvited = [
      for (final row in _notInvited)
        if (row.id != personId) row,
    ];
  }

  Future<void> _inviteNotInvited(Person person) async {
    final email = person.email?.trim() ?? '';
    if (_rowBusyId != null || email.isEmpty) return;
    setState(() {
      _rowBusyId = person.id;
      _rowError.remove(person.id);
    });
    try {
      await _createAndSend(person, email);
    } on InviteApiException catch (error) {
      if (!mounted) return;
      setState(() => _rowError[person.id] = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rowError[person.id] = 'Couldn’t send invite. Try again.');
    } finally {
      if (mounted) setState(() => _rowBusyId = null);
    }
  }

  /// Creates the invite once, then sends it. A second tap after a failed
  /// send retries the email and does not create another invite.
  Future<void> _createAndSend(Person person, String email) async {
    var inviteId = _pendingSend[person.id];
    if (inviteId == null) {
      final created = await _api.createInvite(
        familyId: widget.familyId,
        personId: person.id,
        email: email,
      );
      inviteId = created.inviteId;
      _pendingSend[person.id] = inviteId;
    }
    await _api.sendInviteEmail(inviteId: inviteId);
    _pendingSend.remove(person.id);
    if (!mounted) return;
    setState(() => _dropNotInvited(person.id));
  }

  Future<void> _saveEmailAndInvite(Person person) async {
    final people = widget.people;
    final draft = _emailDrafts[person.id]?.text.trim() ?? '';
    if (people == null || draft.isEmpty || _rowBusyId != null) return;
    setState(() {
      _rowBusyId = person.id;
      _rowError.remove(person.id);
    });
    Person saved;
    try {
      saved = await people.updatePerson(
        personId: person.id,
        name: person.name,
        email: draft,
        writeEmail: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rowBusyId = null;
        _rowError[person.id] = _mappedPeopleSaveError(error);
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _notInvited = [
        for (final row in _notInvited)
          if (row.id == person.id) saved else row,
      ];
      _addingEmail.remove(person.id);
    });
    final email = saved.email?.trim() ?? '';
    if (email.isEmpty) {
      if (mounted) setState(() => _rowBusyId = null);
      return;
    }
    try {
      await _createAndSend(saved, email);
    } on InviteApiException catch (error) {
      if (!mounted) return;
      setState(() => _rowError[person.id] = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rowError[person.id] = 'Couldn’t send invite. Try again.');
    } finally {
      if (mounted) setState(() => _rowBusyId = null);
    }
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _toast('Couldn’t send invite. Try again.');
      return;
    }
    setState(() => _busy = true);
    try {
      // The personal note is on the screen only. send-invite-email has no note.
      final created = await _api.createInvite(
        familyId: widget.familyId,
        email: email,
      );
      await _api.sendInviteEmail(inviteId: created.inviteId);
      if (!mounted) return;
      _toast('Invite sent');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _toast('Couldn’t send invite. Try again.');
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
      final created = await _api.createInvite(
        familyId: widget.familyId,
        personId: personId,
      );
      if (!mounted) return;
      setState(() {
        _linkUrl = created.inviteUrl;
        _linkController.text = created.inviteUrl;
      });
    } catch (_) {
      if (!mounted) return;
      _toast('Couldn’t send invite. Try again.');
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

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
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
          _header(),
          const SizedBox(height: 20),
          _tabs(),
          const SizedBox(height: 20),
          if (_tab == 0) _emailBody(),
          if (_tab == 1) _smsBody(),
          if (_tab == 2) _linkBody(),
          if (_notInvited.isNotEmpty) ...[
            const SizedBox(height: 20),
            _notInvitedSection(),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: albumInk),
          const SizedBox(height: 16),
          _actions(),
          const SizedBox(height: 12),
          Text(
            _footnote,
            textAlign: TextAlign.center,
            style: _InviteType.footnote,
          ),
        ],
      ),
    );
  }

  String get _footnote {
    switch (_tab) {
      case 1:
        return 'We’ll send a short SMS with a secure join link.';
      case 2:
        return 'Share via Messages, Mail, or anywhere — no email required.';
      default:
        return 'Text uses phone number · Link creates a shareable invite URL anyone can open.';
    }
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite to the family archive', style: _InviteType.title),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('Any member can invite', style: _InviteType.meta),
                  Container(
                    key: const Key('invite-family'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: albumSage,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(widget.familyName, style: _InviteType.chip),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('invite-close'),
          onPressed: _busy ? null : _close,
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

  Widget _tabs() {
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
            _tabButton(0, 'Email', 'invite-tab-email'),
            _tabButton(1, 'Text (SMS)', 'invite-tab-sms'),
            _tabButton(2, 'Link', 'invite-tab-link'),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, String keyName) {
    final selected = _tab == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? albumTerracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: Key(keyName),
            borderRadius: BorderRadius.circular(8),
            onTap: _busy ? null : () => _selectTab(index),
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

  Widget _emailBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Email address'),
        const SizedBox(height: 6),
        _field(
          key: const Key('invite-email'),
          controller: _emailController,
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _noteLabel(),
        const SizedBox(height: 6),
        _noteField(
          key: const Key('invite-note'),
          controller: _emailNoteController,
        ),
        const SizedBox(height: 16),
        Text('They’ll join as a family member', style: _InviteType.meta),
      ],
    );
  }

  Widget _smsBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Phone number'),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: albumParchment,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: albumSage),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: albumParchment,
                  border: Border(right: BorderSide(color: albumSage)),
                ),
                child: Text('+1', style: _InviteType.field),
              ),
              Expanded(
                child: TextField(
                  key: const Key('invite-phone'),
                  controller: _phoneController,
                  enabled: !_busy,
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
        ),
        const SizedBox(height: 16),
        _noteLabel(),
        const SizedBox(height: 6),
        _noteField(
          key: const Key('invite-sms-note'),
          controller: _smsNoteController,
        ),
        const SizedBox(height: 16),
        Text('They’ll join as a family member', style: _InviteType.meta),
      ],
    );
  }

  Widget _linkBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Who is this link for?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final person in _unlinked)
              ChoiceChip(
                key: Key('invite-person-${person.id}'),
                label: Text(person.name),
                selected: _pickedPersonId == person.id,
                onSelected: _busy
                    ? null
                    : (_) => _createLink(personId: person.id),
              ),
            ChoiceChip(
              key: const Key('invite-person-new'),
              label: const Text('Someone new'),
              selected: _linkUrl != null && _pickedPersonId == null,
              onSelected: _busy ? null : (_) => _createLink(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _label('Shareable invite link'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('invite-link'),
                readOnly: true,
                controller: _linkController,
                style: _InviteType.mono,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: albumParchment,
                  hintText: _busy ? 'Creating link…' : '',
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
              onPressed: _busy ? null : _copyLink,
              style: _primaryStyle,
              child: const Text('Copy link'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
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
              onPressed: _busy
                  ? null
                  : () => _createLink(personId: _pickedPersonId),
              style: TextButton.styleFrom(
                foregroundColor: albumTerracotta,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh, size: 14),
              label: Text('Generate new link', style: _InviteType.linkAction),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Anyone with the link can request to join; a verified family member still confirms.',
          style: _InviteType.meta,
        ),
      ],
    );
  }

  Widget _notInvitedSection() {
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
        for (final person in _notInvited) _notInvitedRow(person),
      ],
    );
  }

  Widget _notInvitedRow(Person person) {
    final busy = _rowBusyId == person.id;
    final error = _rowError[person.id];
    final adding = _addingEmail.contains(person.id);
    return Padding(
      key: Key('not-invited-row-${person.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                        _hasEmail(person)
                            ? person.email!.trim()
                            : 'No email yet',
                        style: _InviteType.meta,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_hasEmail(person))
                OutlinedButton(
                  key: Key('not-invited-invite-${person.id}'),
                  onPressed: busy ? null : () => _inviteNotInvited(person),
                  style: _smallOutline,
                  child: const Text('Invite'),
                )
              else if (!adding)
                OutlinedButton(
                  key: Key('not-invited-add-${person.id}'),
                  onPressed: busy ? null : () => _startAddEmail(person.id),
                  style: _smallOutline,
                  child: const Text('Add email'),
                ),
            ],
          ),
          if (adding) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    key: Key('not-invited-email-${person.id}'),
                    controller: _emailDrafts[person.id]!,
                    hint: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: Key('not-invited-save-${person.id}'),
                  onPressed: busy ? null : () => _saveEmailAndInvite(person),
                  style: _smallOutline,
                  child: const Text('Save and invite'),
                ),
              ],
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

  void _startAddEmail(String personId) {
    _emailDrafts.putIfAbsent(personId, TextEditingController.new);
    setState(() => _addingEmail.add(personId));
  }

  Widget _actions() {
    final primary = switch (_tab) {
      1 => (
        'Send text invite',
        'invite-sms-send',
        () async => _smsPlaceholder(),
      ),
      2 => ('Done', 'invite-done', () async => _close()),
      _ => ('Send invite', 'invite-send', _sendEmail),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          key: const Key('invite-cancel'),
          onPressed: _busy ? null : _close,
          style: OutlinedButton.styleFrom(
            foregroundColor: albumInk,
            side: const BorderSide(color: albumSage),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: _InviteType.button,
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          key: Key(primary.$2),
          onPressed: _busy ? null : primary.$3,
          style: _primaryStyle,
          child: Text(_primaryLabel(primary.$1)),
        ),
      ],
    );
  }

  String _primaryLabel(String idle) {
    if (!_busy || _tab == 1) return idle;
    return _tab == 0 ? 'Sending…' : 'Working…';
  }

  void _smsPlaceholder() {
    _toast('Text invites are not available yet.');
  }

  Widget _label(String text) {
    return Text(text, style: _InviteType.label);
  }

  Widget _noteLabel() {
    return Text.rich(
      TextSpan(
        text: 'Personal note ',
        style: _InviteType.label,
        children: [TextSpan(text: '(Optional)', style: _InviteType.optional)],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      key: key,
      controller: controller,
      enabled: !_busy,
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

  Widget _noteField({
    required Key key,
    required TextEditingController controller,
  }) {
    return TextField(
      key: key,
      controller: controller,
      enabled: !_busy,
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

  OutlineInputBorder get _fieldBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: albumSage),
  );

  ButtonStyle get _smallOutline => OutlinedButton.styleFrom(
    foregroundColor: albumInk,
    side: const BorderSide(color: albumSage),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: _InviteType.button,
  );

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    backgroundColor: albumTerracotta,
    foregroundColor: albumParchment,
    disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.4),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: _InviteType.buttonBold,
  );
}

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

/// Same four prefixes as mapRpcError in supabase/functions/_shared/manage.ts.
String _mappedPeopleSaveError(Object error) {
  final raw = error is PostgrestException ? error.message : '';
  final trimmed = raw.trim();
  const prefixes = [
    'NOT_FOUND:',
    'FORBIDDEN:',
    'VALIDATION:',
    'INVITE_INVALID:',
  ];
  for (final prefix in prefixes) {
    if (!trimmed.startsWith(prefix)) continue;
    final detail = trimmed.substring(prefix.length).trim();
    return detail.isEmpty ? trimmed : detail;
  }
  return 'Try again';
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/invite_api.dart';

/// Invite dialog matching the Stitch Email, Link, and SMS screens.
/// SMS is visual only until a later milestone.
class InviteModal extends StatefulWidget {
  const InviteModal({
    super.key,
    required this.familyId,
    this.familyName = 'Family',
    this.api,
  });

  final String familyId;
  final String familyName;
  final InviteGateway? api;

  static Future<void> show(
    BuildContext context, {
    required String familyId,
    String familyName = 'Family',
    InviteGateway? api,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x80000000),
      builder: (ctx) => Dialog(
        backgroundColor: _InviteColors.card,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _InviteColors.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 512,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: InviteModal(
            familyId: familyId,
            familyName: familyName,
            api: api,
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
  var _tab = 0;
  var _busy = false;
  String? _linkUrl;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InviteApi();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailNoteController.dispose();
    _phoneController.dispose();
    _smsNoteController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (index == 2) {
      _ensureLink();
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

  Future<void> _ensureLink() async {
    if (_linkUrl != null || _busy) return;
    await _createLink();
  }

  Future<void> _createLink() async {
    setState(() => _busy = true);
    try {
      final created = await _api.createInvite(familyId: widget.familyId);
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
    if (_linkUrl == null) {
      await _ensureLink();
    }
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
          const SizedBox(height: 16),
          const Divider(height: 1, color: _InviteColors.rule),
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
                      color: _InviteColors.chip,
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
            backgroundColor: _InviteColors.well,
            foregroundColor: _InviteColors.muted,
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
        color: _InviteColors.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _InviteColors.border),
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
          color: selected ? _InviteColors.primary : Colors.transparent,
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
            color: _InviteColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _InviteColors.fieldBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: _InviteColors.prefix,
                  border: Border(
                    right: BorderSide(color: _InviteColors.fieldBorder),
                  ),
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
                  fillColor: _InviteColors.well,
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
              onPressed: _busy ? null : _createLink,
              style: TextButton.styleFrom(
                foregroundColor: _InviteColors.primary,
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
            foregroundColor: _InviteColors.secondary,
            side: const BorderSide(color: _InviteColors.cancelBorder),
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
        fillColor: _InviteColors.card,
        border: _fieldBorder,
        enabledBorder: _fieldBorder,
        focusedBorder: _fieldBorder.copyWith(
          borderSide: const BorderSide(color: _InviteColors.primary),
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
        fillColor: _InviteColors.card,
        alignLabelWithHint: true,
        border: _fieldBorder,
        enabledBorder: _fieldBorder,
        focusedBorder: _fieldBorder.copyWith(
          borderSide: const BorderSide(color: _InviteColors.primary),
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
    borderSide: const BorderSide(color: _InviteColors.fieldBorder),
  );

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    backgroundColor: _InviteColors.primary,
    foregroundColor: _InviteColors.onPrimary,
    disabledBackgroundColor: _InviteColors.primary.withValues(alpha: 0.4),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: _InviteType.buttonBold,
  );
}

abstract final class _InviteColors {
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF6B5B55);
  static const onPrimary = Color(0xFFFFF6F3);
  static const ink = Color(0xFF37312F);
  static const muted = Color(0xFF655E5B);
  static const secondary = Color(0xFF665D5A);
  static const chip = Color(0xFFEDE0DC);
  static const chipInk = Color(0xFF58504D);
  static const well = Color(0xFFF5ECE9);
  static const prefix = Color(0x80F5ECE9);
  static const border = Color(0x4DB9B0AD);
  static const fieldBorder = Color(0x66B9B0AD);
  static const cancelBorder = Color(0x80B9B0AD);
  static const rule = Color(0x33B9B0AD);
}

abstract final class _InviteType {
  static final title = GoogleFonts.newsreader(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: _InviteColors.ink,
    height: 1.2,
  );
  static final label = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: _InviteColors.ink,
  );
  static final optional = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: _InviteColors.muted,
  );
  static final meta = GoogleFonts.sourceSans3(
    fontSize: 12,
    color: _InviteColors.muted,
  );
  static final chip = GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _InviteColors.chipInk,
  );
  static final field = GoogleFonts.sourceSans3(
    fontSize: 14,
    color: _InviteColors.ink,
  );
  static final hint = GoogleFonts.sourceSans3(
    fontSize: 14,
    color: _InviteColors.muted.withValues(alpha: 0.7),
  );
  static final mono = GoogleFonts.sourceSans3(
    fontSize: 14,
    color: _InviteColors.ink,
  );
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
    color: _InviteColors.primary,
  );
  static final footnote = GoogleFonts.sourceSans3(
    fontSize: 11,
    color: _InviteColors.muted,
  );

  static TextStyle tab(bool selected) {
    return GoogleFonts.sourceSans3(
      fontSize: 12,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: selected ? _InviteColors.onPrimary : _InviteColors.muted,
    );
  }
}

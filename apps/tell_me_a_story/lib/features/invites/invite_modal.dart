import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/album_chrome.dart';
import '../../data/invite_api.dart';

/// Invite modal — Email + Link only (chrome locks). No SMS.
class InviteModal extends StatefulWidget {
  const InviteModal({super.key, required this.familyId, this.api});

  final String familyId;
  final InviteGateway? api;

  static Future<void> show(
    BuildContext context, {
    required String familyId,
    InviteGateway? api,
  }) {
    return showAlbumDialog<void>(
      context: context,
      maxWidth: 480,
      builder: (ctx) => InviteModal(familyId: familyId, api: api),
    );
  }

  @override
  State<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends State<InviteModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _emailController = TextEditingController();
  late final InviteGateway _api;
  var _busy = false;
  String? _linkUrl;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _api = widget.api ?? InviteApi();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _toast('Couldn’t send invite. Try again.');
      return;
    }
    setState(() => _busy = true);
    try {
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

  Future<void> _createLink() async {
    setState(() => _busy = true);
    try {
      final created = await _api.createInvite(familyId: widget.familyId);
      if (!mounted) return;
      setState(() => _linkUrl = created.inviteUrl);
    } catch (_) {
      if (!mounted) return;
      _toast('Couldn’t send invite. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    final url = _linkUrl;
    if (url == null || url.isEmpty) {
      await _createLink();
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _toast('Link copied');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite to the family archive',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Email'),
                Tab(text: 'Link'),
              ],
            ),
            SizedBox(
              height: 148,
              child: TabBarView(
                controller: _tabs,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_busy,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _sendEmail,
                          child: Text(_busy ? 'Sending…' : 'Send invite'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_linkUrl != null)
                          SelectableText(_linkUrl!, maxLines: 3),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (_linkUrl == null) {
                                    await _createLink();
                                  }
                                  if (_linkUrl != null) await _copyLink();
                                },
                          child: Text(
                            _busy
                                ? 'Working…'
                                : (_linkUrl == null
                                      ? 'Create link'
                                      : 'Copy link'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

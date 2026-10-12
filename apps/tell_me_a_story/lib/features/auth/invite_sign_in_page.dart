import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/router/auth_refresh.dart';
import '../../core/theme/album_theme.dart';
import '../../data/family_selection.dart';
import '../../data/invite_api.dart';
import '../family/family_role.dart';
import 'magic_link_page.dart';
import 'magic_link_redirect.dart';

const inviteDeadLink =
    'This invite link no longer works. Ask your family for a new one.';

/// Public `/invite/:token` sign-in. Accepts once when a session is present.
class InviteSignInPage extends StatefulWidget {
  const InviteSignInPage({
    super.key,
    required this.token,
    this.previewApi,
    this.inviteApi,
    this.sender,
    this.authRefresh,
    this.signedIn,
  });

  final String token;
  final InviteLinkGateway? previewApi;
  final InviteGateway? inviteApi;
  final MagicLinkSender? sender;
  final AuthRefresh? authRefresh;
  final bool Function()? signedIn;

  @override
  State<InviteSignInPage> createState() => _InviteSignInPageState();
}

class _InviteSignInPageState extends State<InviteSignInPage> {
  final _email = TextEditingController();
  InvitePreview? _preview;
  var _loading = true;
  var _sending = false;
  var _sent = false;
  var _accepting = false;
  var _accepted = false;
  String? _error;
  String? _sentTo;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isSignedIn => widget.signedIn?.call() ?? false;

  @override
  void initState() {
    super.initState();
    widget.authRefresh?.addListener(_onAuth);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    widget.authRefresh?.removeListener(_onAuth);
    _email.dispose();
    super.dispose();
  }

  void _onAuth() {
    if (_isSignedIn && _preview?.valid == true) {
      _accept();
    }
  }

  Future<void> _load() async {
    try {
      final api = widget.previewApi ?? InviteLinkApi();
      final preview = await api.validateInviteToken(widget.token);
      if (!mounted) return;
      setState(() {
        _preview = preview.valid ? preview : const InvitePreview(valid: false);
        _loading = false;
      });
      if (preview.valid && _isSignedIn) await _accept();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = const InvitePreview(valid: false);
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    if (_accepting || _accepted) return;
    final invites = widget.inviteApi;
    if (invites == null) {
      setState(() => _preview = const InvitePreview(valid: false));
      return;
    }
    _accepting = true;
    try {
      final result = await invites.acceptInvite(token: widget.token);
      _accepted = true;
      if (!mounted) return;
      FamilySelection.remember(result.familyId);
      context.go(AppRoutes.timeline);
    } catch (_) {
      _accepting = false;
      if (!mounted) return;
      setState(() => _preview = const InvitePreview(valid: false));
    }
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Please enter a full email address.');
      return;
    }
    final sender = widget.sender;
    if (sender == null) {
      setState(() => _error = 'Request failed');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final origin = magicLinkEmailRedirectTo();
      await sender.send(
        email,
        redirectTo: '$origin/invite/${Uri.encodeComponent(widget.token)}',
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sentTo = email;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Request failed');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _loading
                  ? const CircularProgressIndicator()
                  : _card(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ThemeData theme) {
    final preview = _preview;
    if (preview == null || !preview.valid) {
      return Text(
        inviteDeadLink,
        key: const Key('invite-dead'),
        style: theme.textTheme.bodyLarge?.copyWith(color: albumInk),
      );
    }
    final family = (preview.familyName ?? '').trim();
    final familyLabel = family.isEmpty ? 'this family' : family;
    final inviter = (preview.inviterName ?? '').trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FamilyMonogram(name: familyLabel, size: 56),
            ),
            const SizedBox(height: 16),
            Text(
              "YOU'RE INVITED",
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: albumTerracotta,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join $familyLabel',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: albumInk,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$familyLabel keeps its stories on Tell Me a Story. Sign in with your email to read them and add your own.',
              style: theme.textTheme.bodyMedium?.copyWith(color: albumInk),
            ),
            if (inviter.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '$inviter invited you to $familyLabel.',
                key: const Key('invite-inviter'),
              ),
            ],
            const SizedBox(height: 16),
            if (_isSignedIn)
              const Center(child: CircularProgressIndicator())
            else if (_sent)
              Text(
                'We sent a sign-in link to $_sentTo. Tap it to join $familyLabel.',
                key: const Key('invite-sent'),
              )
            else ...[
              TextField(
                key: const Key('invite-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                enabled: !_sending,
                onSubmitted: (_) => _send(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: albumTerracotta)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Sending…' : 'Email me a sign-in link'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/album_theme.dart';
import 'magic_link_redirect.dart';

/// Sends a magic-link email. Tests inject this instead of [GoTrueClient].
abstract class MagicLinkSender {
  Future<void> send(String email, {required String redirectTo});
}

class GoTrueMagicLinkSender implements MagicLinkSender {
  GoTrueMagicLinkSender(this.auth);

  final GoTrueClient auth;

  @override
  Future<void> send(String email, {required String redirectTo}) {
    return auth.signInWithOtp(email: email, emailRedirectTo: redirectTo);
  }
}

/// Signed-out landing. Signed-in visitors are redirected by the router.
class MagicLinkPage extends StatefulWidget {
  const MagicLinkPage({super.key, this.auth, this.sender});

  /// Injectable for tests; defaults to [Supabase.instance.client.auth].
  final GoTrueClient? auth;

  /// When set, used instead of [auth].
  final MagicLinkSender? sender;

  @override
  State<MagicLinkPage> createState() => _MagicLinkPageState();
}

class _MagicLinkPageState extends State<MagicLinkPage> {
  final _emailController = TextEditingController();
  var _sending = false;
  var _sent = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  MagicLinkSender get _sender =>
      widget.sender ??
      GoTrueMagicLinkSender(widget.auth ?? Supabase.instance.client.auth);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestMagicLink() async {
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Please enter a full email address.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _sender.send(email, redirectTo: magicLinkEmailRedirectTo());
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message.isEmpty ? 'Request failed' : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Request failed');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _useDifferentEmail() {
    setState(() {
      _sent = false;
      _error = null;
      _sending = false;
    });
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Your family's stories, kept together.",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: albumInk,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: albumInk.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: _sent ? _sentCard(theme) : _form(theme),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Private to your family. Stories stay inside the family you share them with.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: albumInk.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in or get started',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: albumInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email to access your family archive.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: albumInk.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('magic-link-email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
          enabled: !_sending,
          onSubmitted: (_) => _requestMagicLink(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: albumTerracotta,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending ? null : _requestMagicLink,
          child: Text(_sending ? 'Sending…' : 'Email me a sign-in link'),
        ),
      ],
    );
  }

  Widget _sentCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Check your email',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: albumInk,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const Key('magic-link-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: albumTerracotta,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending ? null : _requestMagicLink,
          child: Text(_sending ? 'Sending…' : 'Send it again'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _sending ? null : _useDifferentEmail,
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}

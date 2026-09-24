import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'magic_link_redirect.dart';

/// Signed-out magic-link entry.
///
/// OPEN (Mugatu): exact chrome-lock field/button copy not available in repo;
/// using minimal functional labels only.
class MagicLinkPage extends StatefulWidget {
  const MagicLinkPage({super.key, this.auth});

  /// Injectable for tests; defaults to [Supabase.instance.client.auth].
  final GoTrueClient? auth;

  @override
  State<MagicLinkPage> createState() => _MagicLinkPageState();
}

class _MagicLinkPageState extends State<MagicLinkPage> {
  final _emailController = TextEditingController();
  var _sending = false;
  String? _message;

  GoTrueClient get _auth => widget.auth ?? Supabase.instance.client.auth;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Email is required');
      return;
    }

    setState(() {
      _sending = true;
      _message = null;
    });

    try {
      await _auth.signInWithOtp(
        email: email,
        emailRedirectTo: magicLinkEmailRedirectTo(),
      );
      if (!mounted) return;
      setState(() => _message = 'Check your email for the magic link');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Request failed');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                enabled: !_sending,
                onSubmitted: (_) => _requestMagicLink(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : _requestMagicLink,
                child: Text(_sending ? 'Sending…' : 'Send magic link'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

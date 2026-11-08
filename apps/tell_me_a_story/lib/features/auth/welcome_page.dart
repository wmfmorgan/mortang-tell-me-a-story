import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
import 'package:tell_me_a_story/features/auth/sign_in_code_form.dart';

const welcomeHeading = 'Welcome to Tell Me a Story';
const welcomeBody = 'What should your family call you?';
const welcomeNameLabel = 'Your name';
const welcomeContinueLabel = 'Continue';
const welcomeSavingLabel = 'Saving…';
const welcomeNameRequired = 'Name is required';
const welcomeSaveFailed = 'Couldn’t save your profile. Try again.';

/// Signed-in first-run step at `/welcome`: the account has no display name
/// yet (owner decision A2). Saving the name continues to [startPath].
class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.startPath,
    this.profileApi,
    this.onSignOut,
  });

  /// Where to go once the name is saved (the router passes `appStartPath`).
  final Future<String> Function() startPath;

  /// Defaults to [ProfileApi].
  final ProfileGateway? profileApi;

  /// Defaults to `AppSession.instance.signOut`.
  final Future<void> Function()? onSignOut;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _name = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = welcomeNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.profileApi ?? ProfileApi()).saveName(name);
      final session = ProfileSession.instance;
      session.apply(displayName: name, email: session.email, keepAvatar: true);
      final next = await widget.startPath();
      if (mounted) context.go(next);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = welcomeSaveFailed;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await (widget.onSignOut ?? AppSession.instance.signOut)();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('welcome-page'),
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
                    welcomeHeading,
                    style: GoogleFonts.newsreader(
                      color: albumInk,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    welcomeBody,
                    style: GoogleFonts.sourceSans3(
                      color: albumInk,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('welcome-name'),
                    controller: _name,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _continue(),
                    style: GoogleFonts.literata(color: albumInk, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: welcomeNameLabel,
                      errorText: _error,
                      filled: true,
                      fillColor: albumWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(albumCardRadius),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('welcome-continue'),
                    style: FilledButton.styleFrom(
                      backgroundColor: albumTerracotta,
                      foregroundColor: albumOnAccent,
                    ),
                    onPressed: _saving ? null : _continue,
                    child: Text(
                      _saving ? welcomeSavingLabel : welcomeContinueLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const Key('welcome-sign-out'),
                    style: TextButton.styleFrom(
                      foregroundColor: albumTerracotta,
                    ),
                    onPressed: _saving ? null : _signOut,
                    child: const Text(useDifferentEmailLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

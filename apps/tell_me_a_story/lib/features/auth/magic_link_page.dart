import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/album_theme.dart';
import 'magic_link_redirect.dart';

const _landingInkMuted = albumInk;
const _landingLine = Color(0xFFB9B0AD);
const _landingField = albumParchment;
const _landingOnPrimary = Color(0xFFFFF6F3);

const landingHeadline = 'Your family’s stories, kept together.';
const landingSubhead =
    'A private place to write down the moments you remember, and read the ones your family remembers too.';
const landingPasswordNote = "We'll email you a link. No password needed.";

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
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _wordmark(wide),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 64 : 24,
                              wide ? 24 : 8,
                              wide ? 64 : 24,
                              wide ? 48 : 32,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1280,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: wide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 7,
                                            child: _storyColumn(wide),
                                          ),
                                          const SizedBox(width: 64),
                                          Expanded(
                                            flex: 5,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _signInCard(),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _storyColumn(wide),
                                          const SizedBox(height: 40),
                                          _signInCard(),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _footer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _wordmark(bool wide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 64 : 32, 32, wide ? 64 : 32, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Tell Me a Story',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _storyColumn(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          landingHeadline,
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: wide ? 60 : 36,
            fontWeight: FontWeight.w400,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Text(
            landingSubhead,
            style: GoogleFonts.literata(
              color: _landingInkMuted,
              fontSize: wide ? 20 : 18,
              fontWeight: FontWeight.w300,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _photoCard(),
      ],
    );
  }

  Widget _photoCard() {
    return Transform.rotate(
      angle: -1 * math.pi / 180,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _landingLine.withValues(alpha: 0.3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.asset(
                      'assets/landing/blackberry-picking.jpg',
                      fit: BoxFit.cover,
                      semanticLabel:
                          'A family picking blackberries in a sunlit field',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'blackberry picking at the farm',
                          style: GoogleFonts.newsreader(
                            color: _landingInkMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'summer, 1974',
                        style: GoogleFonts.sourceSans3(
                          color: _landingInkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signInCard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _landingLine.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: _sent ? _sentCard() : _form(),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in or get started',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email to access your family archive.',
          style: GoogleFonts.literata(
            color: _landingInkMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Email address',
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('magic-link-email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !_sending,
          onSubmitted: (_) => _requestMagicLink(),
          style: GoogleFonts.literata(color: albumInk, fontSize: 16),
          cursorColor: albumTerracotta,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: GoogleFonts.literata(
              color: albumSage.withValues(alpha: 0.7),
              fontSize: 16,
            ),
            filled: true,
            fillColor: _landingField,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: _fieldBorder(1),
            enabledBorder: _fieldBorder(1),
            focusedBorder: _fieldBorder(2, albumTerracotta),
            disabledBorder: _fieldBorder(1),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: GoogleFonts.literata(
              color: albumTerracotta,
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _primaryButton(
          label: _sending ? 'Sending…' : 'Email me a sign-in link',
          showArrow: !_sending,
          onPressed: _sending ? null : _requestMagicLink,
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _landingLine.withValues(alpha: 0.2)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              landingPasswordNote,
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                color: _landingInkMuted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sentCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Check your email',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const Key('magic-link-error'),
            style: GoogleFonts.literata(
              color: albumTerracotta,
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _primaryButton(
          label: _sending ? 'Sending…' : 'Send it again',
          showArrow: false,
          onPressed: _sending ? null : _requestMagicLink,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _sending ? null : _useDifferentEmail,
          child: Text(
            'Use a different email',
            style: GoogleFonts.sourceSans3(
              color: albumTerracotta,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required bool showArrow,
    required VoidCallback? onPressed,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: _landingOnPrimary,
        disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.55),
        disabledForegroundColor: _landingOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.sourceSans3(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _landingOnPrimary,
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(double width, [Color? color]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: color ?? _landingLine.withValues(alpha: 0.6),
        width: width,
      ),
    );
  }

  Widget _footer() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _landingLine.withValues(alpha: 0.1)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Text(
          'Private to your family. Stories stay inside the family you share them with.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSans3(
            color: _landingInkMuted,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';
import 'package:tell_me_a_story/features/auth/presentation/sign_in_code_form.dart';

const _landingInkMuted = albumInk;
const _landingLine = albumLandingLine;
const _landingField = albumParchment;
const _landingOnPrimary = albumOnAccent;

const landingHeadline = 'Your family’s stories, kept together.';
const landingSubhead =
    'A private place to write down the moments you remember, and read the ones your family remembers too.';
const landingPasswordNote =
    "We'll email you a 6-digit code. No password needed.";
const sendCodeLabel = 'Email me a sign-in code';
const sendingCodeLabel = 'Sending…';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Whether [email] (already trimmed) looks like a full address.
bool isFullEmail(String email) => _emailPattern.hasMatch(email);

/// Signed-out landing. Signed-in visitors are redirected by the router.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailController = TextEditingController();
  var _sending = false;
  var _signingIn = false;
  String? _requestId;
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!isFullEmail(email)) {
      setState(() => _error = invalidEmailMessage);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final requestId = await ref.read(otpSignInProvider).sendCode(email);
      if (!mounted) return;
      setState(() {
        _requestId = requestId;
        _sentTo = email;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signIn(String code) async {
    final requestId = _requestId;
    if (requestId == null) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      // Success changes the auth session; the router leaves this page.
      await ref
          .read(otpSignInProvider)
          .signIn(requestId: requestId, code: code);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _useDifferentEmail() {
    setState(() {
      _requestId = null;
      _sentTo = null;
      _error = null;
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _SignInCard(
      child: _requestId != null
          ? _CodeStep(
              sentTo: _sentTo,
              signingIn: _signingIn,
              sending: _sending,
              error: _error,
              onSubmit: _signIn,
              onResend: _sendCode,
              onUseDifferentEmail: _useDifferentEmail,
            )
          : _EmailStep(
              controller: _emailController,
              sending: _sending,
              error: _error,
              onSend: _sendCode,
            ),
    );
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _LandingLayout(constraints: constraints, card: card),
        ),
      ),
    );
  }
}

class _LandingLayout extends StatelessWidget {
  const _LandingLayout({required this.constraints, required this.card});

  final BoxConstraints constraints;
  final Widget card;

  @override
  Widget build(BuildContext context) {
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
                  _Wordmark(wide: wide),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 64 : 24,
                      wide ? 24 : 8,
                      wide ? 64 : 24,
                      wide ? 48 : 32,
                    ),
                    child: _LandingBody(wide: wide, card: card),
                  ),
                ],
              ),
              const _LandingFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody({required this.wide, required this.card});

  final bool wide;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: SizedBox(
          width: double.infinity,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 7, child: _StoryColumn(wide: wide)),
                    const SizedBox(width: 64),
                    Expanded(
                      flex: 5,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: card,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StoryColumn(wide: wide),
                    const SizedBox(height: 40),
                    card,
                  ],
                ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
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
}

class _StoryColumn extends StatelessWidget {
  const _StoryColumn({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
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
        const _PhotoCard(),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: albumWhite,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _landingLine.withValues(alpha: 0.3)),
    boxShadow: [
      BoxShadow(
        color: albumShadow.withAlpha(0x0D),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -1 * math.pi / 180,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: DecoratedBox(
          decoration: _cardDecoration(),
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
                const _PhotoCaption(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCaption extends StatelessWidget {
  const _PhotoCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: DecoratedBox(
        decoration: _cardDecoration(),
        child: Padding(padding: const EdgeInsets.all(40), child: child),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.controller,
    required this.sending,
    required this.error,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final String? error;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EmailStepIntro(),
        const SizedBox(height: 8),
        _EmailField(controller: controller, sending: sending, onSend: onSend),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: GoogleFonts.literata(color: albumTerracotta, fontSize: 14),
          ),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: sending ? sendingCodeLabel : sendCodeLabel,
          showArrow: !sending,
          onPressed: sending ? null : onSend,
        ),
        const SizedBox(height: 16),
        const _PasswordNote(),
      ],
    );
  }
}

class _EmailStepIntro extends StatelessWidget {
  const _EmailStepIntro();

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('magic-link-email'),
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      enabled: !sending,
      onSubmitted: (_) => onSend(),
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
    );
  }
}

class _PasswordNote extends StatelessWidget {
  const _PasswordNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.sentTo,
    required this.signingIn,
    required this.sending,
    required this.error,
    required this.onSubmit,
    required this.onResend,
    required this.onUseDifferentEmail,
  });

  final String? sentTo;
  final bool signingIn;
  final bool sending;
  final String? error;
  final void Function(String code) onSubmit;
  final VoidCallback onResend;
  final VoidCallback onUseDifferentEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          signInCodeHeading,
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SignInCodeForm(
          message: 'We sent a 6-digit code to $sentTo.',
          signingIn: signingIn,
          sending: sending,
          error: error,
          onSubmit: onSubmit,
          onResend: onResend,
          onUseDifferentEmail: onUseDifferentEmail,
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.showArrow,
    required this.onPressed,
  });

  final String label;
  final bool showArrow;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
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

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
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

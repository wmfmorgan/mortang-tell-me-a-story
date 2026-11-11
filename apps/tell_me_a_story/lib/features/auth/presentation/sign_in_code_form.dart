import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

const signInCodeHeading = 'Check your email';
const signInCodeLabel = 'Sign-in code';
const signInButtonLabel = 'Sign in';
const signingInLabel = 'Signing in…';
const sendNewCodeLabel = 'Send a new code';
const useDifferentEmailLabel = 'Use a different email';

/// The code step of email sign-in: where the code went, the code field,
/// Sign in, and the two ways back. Shared by the landing and invite pages.
class SignInCodeForm extends StatefulWidget {
  const SignInCodeForm({
    super.key,
    required this.message,
    this.messageKey,
    required this.signingIn,
    required this.sending,
    required this.error,
    required this.onSubmit,
    required this.onResend,
    required this.onUseDifferentEmail,
  });

  /// Where the code went, e.g. "We sent a 6-digit code to a@b.co."
  final String message;
  final Key? messageKey;
  final bool signingIn;
  final bool sending;
  final String? error;
  final void Function(String code) onSubmit;
  final VoidCallback onResend;
  final VoidCallback onUseDifferentEmail;

  @override
  State<SignInCodeForm> createState() => _SignInCodeFormState();
}

class _SignInCodeFormState extends State<SignInCodeForm> {
  final _code = TextEditingController();

  bool get _busy => widget.signingIn || widget.sending;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim();
    if (code.isEmpty || _busy) return;
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CodeMessage(message: widget.message, messageKey: widget.messageKey),
        const SizedBox(height: 20),
        const _CodeLabel(),
        const SizedBox(height: 8),
        _CodeField(
          controller: _code,
          enabled: !widget.signingIn,
          onSubmitted: _submit,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _CodeError(error: error),
        ],
        const SizedBox(height: 20),
        _SubmitButton(
          signingIn: widget.signingIn,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 8),
        _BackLinks(
          onResend: _busy ? null : widget.onResend,
          onUseDifferentEmail: _busy ? null : widget.onUseDifferentEmail,
        ),
      ],
    );
  }
}

class _CodeMessage extends StatelessWidget {
  const _CodeMessage({required this.message, required this.messageKey});

  final String message;
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: messageKey,
      style: GoogleFonts.literata(
        color: albumInk.withValues(alpha: 0.8),
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}

class _BackLinks extends StatelessWidget {
  const _BackLinks({required this.onResend, required this.onUseDifferentEmail});

  final VoidCallback? onResend;
  final VoidCallback? onUseDifferentEmail;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        _SecondaryButton(label: sendNewCodeLabel, onPressed: onResend),
        _SecondaryButton(
          label: useDifferentEmailLabel,
          onPressed: onUseDifferentEmail,
        ),
      ],
    );
  }
}

class _CodeLabel extends StatelessWidget {
  const _CodeLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      signInCodeLabel,
      style: GoogleFonts.sourceSans3(
        color: albumInk,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CodeError extends StatelessWidget {
  const _CodeError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Text(
      error,
      key: const Key('sign-in-error'),
      style: GoogleFonts.literata(color: albumTerracotta, fontSize: 14),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('sign-in-code'),
      controller: controller,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      enabled: enabled,
      onSubmitted: (_) => onSubmitted(),
      style: GoogleFonts.sourceSans3(
        color: albumInk,
        fontSize: 20,
        letterSpacing: 6,
      ),
      cursorColor: albumTerracotta,
      decoration: InputDecoration(
        filled: true,
        fillColor: albumParchment,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _border(1, albumModalBorder),
        enabledBorder: _border(1, albumModalBorder),
        focusedBorder: _border(2, albumTerracotta),
        disabledBorder: _border(1, albumModalBorder),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.signingIn, required this.onPressed});

  final bool signingIn;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('sign-in-code-submit'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.55),
        disabledForegroundColor: albumParchment,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        signingIn ? signingInLabel : signInButtonLabel,
        style: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: albumParchment,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.sourceSans3(
          color: albumTerracotta,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

OutlineInputBorder _border(double width, Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: width),
  );
}

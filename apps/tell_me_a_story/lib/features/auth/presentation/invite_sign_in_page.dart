import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_preview.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/app_session_provider.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';
import 'package:tell_me_a_story/features/auth/presentation/invite_preview_provider.dart';
import 'package:tell_me_a_story/features/auth/presentation/sign_in_code_form.dart';
import 'package:tell_me_a_story/features/auth/presentation/sign_in_page.dart';

const _inviteSage = Color(0xFF7A8B74);
const _inviteOutline = albumSage;
const _inviteLine = Color(0xFFB9B0AD);
const _inviteCard = Color(0xFFF5DED6);
const _inviteOnPrimary = Color(0xFFFFFFFF);

const inviteDeadLink =
    'This invite link no longer works. Ask your family for a new one.';
const inviteRetryLabel = 'Try again';

/// Public `/invite/:token` sign-in. Accepts once when a session is present.
class InviteSignInPage extends ConsumerStatefulWidget {
  const InviteSignInPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteSignInPage> createState() => _InviteSignInPageState();
}

class _InviteSignInPageState extends ConsumerState<InviteSignInPage> {
  final _email = TextEditingController();
  late final AuthRefresh _auth = ref.read(authRefreshProvider);
  ProviderSubscription<AsyncValue<InvitePreview>>? _previewSubscription;
  var _sessionChecked = false;
  var _sending = false;
  var _signingIn = false;
  var _accepting = false;
  var _accepted = false;
  String? _error;
  String? _requestId;
  String? _sentTo;

  /// Shown instead of the card when accepting failed.
  _InviteFailure? _failure;

  bool get _isSignedIn => _auth.isSignedIn;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _email.dispose();
    super.dispose();
  }

  void _onAuth() {
    if (_isSignedIn) _accept();
  }

  Future<void> _start() async {
    // A session is enough to join. Validate first would hide a repeat open
    // of an invite this person already accepted behind the dead-link copy.
    if (_isSignedIn) {
      await _accept();
      if (mounted && !_accepted) setState(() => _sessionChecked = true);
      return;
    }
    _previewSubscription ??= ref.listenManual(
      invitePreviewProvider(widget.token),
      (_, next) => _onPreview(next),
    );
    setState(() => _sessionChecked = true);
  }

  void _onPreview(AsyncValue<InvitePreview> next) {
    if (next case AsyncError(:final error, :final stackTrace)
        when error is! AppException) {
      _report(error, stackTrace);
    }
    final valid = next.value?.valid ?? false;
    if (valid && _isSignedIn) _accept();
  }

  Future<void> _accept() async {
    if (_accepting || _accepted) return;
    _accepting = true;
    try {
      final result = await ref
          .read(inviteRepositoryProvider)
          .acceptInvite(token: widget.token);
      _accepted = true;
      if (!mounted) return;
      ref.read(familySelectionProvider.notifier).remember(result.familyId);
      context.go(AppRoutes.familyLanding);
    } catch (error, stack) {
      // Boundary: a server refusal shows its reason; anything else is
      // reported and offers Try again.
      _accepting = false;
      if (error is! AppException) _report(error, stack);
      if (!mounted) return;
      setState(() {
        _failure = error is AppException
            ? _InviteFailure(message: error.message, retry: false)
            : const _InviteFailure(message: signInRequestFailed, retry: true);
      });
    }
  }

  void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'invite sign-in',
      ),
    );
  }

  void _retry() {
    ref.invalidate(invitePreviewProvider(widget.token));
    setState(() {
      _failure = null;
      _sessionChecked = false;
    });
    _start();
  }

  /// Signs out the account the invite refused, then shows the email form.
  Future<void> _switchAccount() async {
    await ref.read(appSessionProvider).signOut();
    if (!mounted) return;
    setState(() {
      _failure = null;
      _accepted = false;
      _requestId = null;
      _sentTo = null;
      _error = null;
      _sessionChecked = false;
    });
    await _start();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
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

  /// Success changes the auth session; [_onAuth] then accepts the invite.
  Future<void> _signIn(String code) async {
    final requestId = _requestId;
    if (requestId == null) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final Widget card;
    if (!_sessionChecked) {
      card = const _Spinner();
    } else if (failure != null) {
      card = _FailureCard(
        message: failure.message,
        onRetry: failure.retry ? _retry : null,
        onSwitchAccount: _isSignedIn ? _switchAccount : null,
      );
    } else {
      card = _PreviewCard(
        token: widget.token,
        onRetry: _retry,
        actionBuilder: (familyLabel) => _InviteAction(
          familyLabel: familyLabel,
          signedIn: _isSignedIn,
          requestId: _requestId,
          sentTo: _sentTo,
          email: _email,
          sending: _sending,
          signingIn: _signingIn,
          error: _error,
          onSend: _sendCode,
          onSubmit: _signIn,
          onUseDifferentEmail: _useDifferentEmail,
        ),
      );
    }
    return _InviteScaffold(card: card);
  }
}

/// Why accepting or loading the invite failed, and whether retrying helps.
class _InviteFailure {
  const _InviteFailure({required this.message, required this.retry});

  final String message;
  final bool retry;
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(color: albumTerracotta);
  }
}

class _InviteScaffold extends StatelessWidget {
  const _InviteScaffold({required this.card});

  final Widget card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _InviteLayout(constraints: constraints, card: card),
        ),
      ),
    );
  }
}

class _InviteLayout extends StatelessWidget {
  const _InviteLayout({required this.constraints, required this.card});

  final BoxConstraints constraints;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final wide = constraints.maxWidth >= 768;
    final gutter = wide ? 40.0 : 24.0;
    final cardWidth = (constraints.maxWidth - gutter * 2).clamp(0.0, 420.0);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: SizedBox(
          width: constraints.maxWidth,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Wordmark(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: SizedBox(width: cardWidth, child: card),
                  ),
                ),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: SizedBox(
          width: double.infinity,
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
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Private to your family. Stories stay inside the family you share them with.',
      textAlign: TextAlign.center,
      style: GoogleFonts.literata(color: _inviteOutline, fontSize: 12),
    );
  }
}

/// The preview card: loading, dead link, a retryable failure, or the live
/// invite.
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({
    required this.token,
    required this.onRetry,
    required this.actionBuilder,
  });

  final String token;
  final VoidCallback onRetry;

  /// Builds the sign-in action for the family's display label.
  final Widget Function(String familyLabel) actionBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(invitePreviewProvider(token))
        .when(
          loading: () => const _Spinner(),
          error: (error, _) => error is AppException
              ? const _DeadCard()
              : _FailureCard(message: signInRequestFailed, onRetry: onRetry),
          data: (preview) {
            if (!preview.valid) return const _DeadCard();
            final family = (preview.familyName ?? '').trim();
            final familyLabel = family.isEmpty ? 'this family' : family;
            return _LiveCard(
              familyLabel: familyLabel,
              inviter: (preview.inviterName ?? '').trim(),
              action: actionBuilder(familyLabel),
            );
          },
        );
  }
}

/// Accepting or loading failed: the reason, then Try again or a switch to
/// another account.
class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.message,
    this.onRetry,
    this.onSwitchAccount,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    final switchAccount = onSwitchAccount;
    return _Shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            key: const Key('invite-failure'),
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              color: albumInk.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 16),
          if (retry != null)
            _TextAction(
              key: const Key('invite-retry'),
              label: inviteRetryLabel,
              onPressed: retry,
            )
          else if (switchAccount != null)
            _TextAction(
              key: const Key('invite-switch-account'),
              label: useDifferentEmailLabel,
              onPressed: switchAccount,
            ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

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

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _inviteCard.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _inviteOutline.withValues(alpha: 0.2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: const EdgeInsets.all(32), child: child),
        ),
      ),
    );
  }
}

class _DeadCard extends StatelessWidget {
  const _DeadCard();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Text(
        inviteDeadLink,
        key: const Key('invite-dead'),
        textAlign: TextAlign.center,
        style: GoogleFonts.literata(
          color: albumInk.withValues(alpha: 0.8),
          fontSize: 14,
          height: 1.625,
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.familyLabel,
    required this.inviter,
    required this.action,
  });

  final String familyLabel;
  final String inviter;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Column(
        children: [
          _Monogram(familyLabel: familyLabel),
          const SizedBox(height: 24),
          _InviteHeading(familyLabel: familyLabel),
          if (inviter.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$inviter invited you to $familyLabel.',
              key: const Key('invite-inviter'),
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(color: albumTerracotta, fontSize: 16),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            '$familyLabel keeps its stories on Tell Me a Story. Sign in with your email to read them and add your own.',
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              color: albumInk.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.625,
            ),
          ),
          const SizedBox(height: 32),
          action,
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.familyLabel});

  final String familyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: albumTerracotta.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        familyMonogram(familyLabel),
        style: GoogleFonts.newsreader(
          color: albumTerracotta,
          fontSize: 24,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _InviteHeading extends StatelessWidget {
  const _InviteHeading({required this.familyLabel});

  final String familyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'YOU’RE INVITED',
          style: GoogleFonts.sourceSans3(
            color: _inviteSage,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join $familyLabel',
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Spinner while joining, the code step, or the email step.
class _InviteAction extends StatelessWidget {
  const _InviteAction({
    required this.familyLabel,
    required this.signedIn,
    required this.requestId,
    required this.sentTo,
    required this.email,
    required this.sending,
    required this.signingIn,
    required this.error,
    required this.onSend,
    required this.onSubmit,
    required this.onUseDifferentEmail,
  });

  final String familyLabel;
  final bool signedIn;
  final String? requestId;
  final String? sentTo;
  final TextEditingController email;
  final bool sending;
  final bool signingIn;
  final String? error;
  final VoidCallback onSend;
  final void Function(String code) onSubmit;
  final VoidCallback onUseDifferentEmail;

  @override
  Widget build(BuildContext context) {
    if (signedIn) return const _Spinner();
    if (requestId != null) {
      return SignInCodeForm(
        message: 'We sent a code to $sentTo. Enter it to join $familyLabel.',
        messageKey: const Key('invite-sent'),
        signingIn: signingIn,
        sending: sending,
        error: error,
        onSubmit: onSubmit,
        onResend: onSend,
        onUseDifferentEmail: onUseDifferentEmail,
      );
    }
    return _EmailForm(
      controller: email,
      sending: sending,
      error: error,
      onSend: onSend,
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email address',
            style: GoogleFonts.sourceSans3(
              color: albumInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _EmailField(controller: controller, sending: sending, onSend: onSend),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: GoogleFonts.literata(color: albumTerracotta, fontSize: 14),
          ),
        ],
        const SizedBox(height: 16),
        _SendButton(sending: sending, onSend: onSend),
        const SizedBox(height: 16),
        Text(
          landingPasswordNote,
          textAlign: TextAlign.center,
          style: GoogleFonts.literata(color: _inviteOutline, fontSize: 12),
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
      key: const Key('invite-email'),
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      enabled: !sending,
      onSubmitted: (_) => onSend(),
      style: GoogleFonts.literata(color: albumInk, fontSize: 14),
      cursorColor: albumTerracotta,
      decoration: InputDecoration(
        hintText: 'you@example.com',
        hintStyle: GoogleFonts.literata(
          color: _inviteOutline.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: _fieldBorder(1),
        enabledBorder: _fieldBorder(1),
        focusedBorder: _fieldBorder(2, albumTerracotta),
        disabledBorder: _fieldBorder(1),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});

  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: sending ? null : onSend,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: _inviteOnPrimary,
        disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.55),
        disabledForegroundColor: _inviteOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sending ? sendingCodeLabel : sendCodeLabel,
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _inviteOnPrimary,
              ),
            ),
            if (!sending) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 16),
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
      color: color ?? _inviteLine.withValues(alpha: 0.5),
      width: width,
    ),
  );
}

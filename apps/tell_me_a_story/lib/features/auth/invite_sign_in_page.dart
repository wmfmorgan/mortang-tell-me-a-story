import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/data/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/ui/family/family_role.dart';
import 'package:tell_me_a_story/features/auth/magic_link_page.dart';
import 'package:tell_me_a_story/data/otp_sign_in.dart';
import 'package:tell_me_a_story/features/auth/sign_in_code_form.dart';

const _inviteSage = Color(0xFF7A8B74);
const _inviteOutline = albumSage;
const _inviteLine = Color(0xFFB9B0AD);
const _inviteCard = Color(0xFFF5DED6);
const _inviteOnPrimary = Color(0xFFFFFFFF);

const inviteDeadLink =
    'This invite link no longer works. Ask your family for a new one.';

/// Public `/invite/:token` sign-in. Accepts once when a session is present.
class InviteSignInPage extends StatefulWidget {
  const InviteSignInPage({
    super.key,
    required this.token,
    this.previewApi,
    this.inviteApi,
    this.otpSignIn,
    this.authRefresh,
    this.signedIn,
  });

  final String token;
  final InviteLinkGateway? previewApi;
  final InviteGateway? inviteApi;

  /// Injectable for tests; defaults to [ServerOtpSignIn].
  final OtpSignIn? otpSignIn;
  final AuthRefresh? authRefresh;
  final bool Function()? signedIn;

  @override
  State<InviteSignInPage> createState() => _InviteSignInPageState();
}

class _InviteSignInPageState extends State<InviteSignInPage> {
  final _email = TextEditingController();
  late final OtpSignIn _otp = widget.otpSignIn ?? ServerOtpSignIn();
  InvitePreview? _preview;
  var _loading = true;
  var _sending = false;
  var _signingIn = false;
  var _accepting = false;
  var _accepted = false;
  String? _error;
  String? _requestId;
  String? _sentTo;

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
    if (_isSignedIn) _accept();
  }

  Future<void> _load() async {
    // A session is enough to join. Validate first would hide a repeat open
    // of an invite this person already accepted behind the dead-link copy.
    if (_isSignedIn && widget.inviteApi != null) {
      await _accept();
      if (!mounted || _accepted) return;
    }
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
      context.go(AppRoutes.familyLanding);
    } catch (_) {
      _accepting = false;
      if (!mounted) return;
      setState(() => _preview = const InvitePreview(valid: false));
    }
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
      final requestId = await _otp.sendCode(email);
      if (!mounted) return;
      setState(() {
        _requestId = requestId;
        _sentTo = email;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = signInErrorMessage(e));
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
      await _otp.signIn(requestId: requestId, code: code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = signInErrorMessage(e));
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
    return Scaffold(
      backgroundColor: albumParchment,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 768;
            final gutter = wide ? 40.0 : 24.0;
            final cardWidth = (constraints.maxWidth - gutter * 2).clamp(
              0.0,
              420.0,
            );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      gutter,
                      gutter,
                      gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _wordmark(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: SizedBox(
                              width: cardWidth,
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: albumTerracotta,
                                    )
                                  : _card(),
                            ),
                          ),
                        ),
                        _footer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _wordmark() {
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

  Widget _footer() {
    return Text(
      'Private to your family. Stories stay inside the family you share them with.',
      textAlign: TextAlign.center,
      style: GoogleFonts.literata(color: _inviteOutline, fontSize: 12),
    );
  }

  Widget _card() {
    final preview = _preview;
    if (preview == null || !preview.valid) {
      return _shell(
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
    final family = (preview.familyName ?? '').trim();
    final familyLabel = family.isEmpty ? 'this family' : family;
    final inviter = (preview.inviterName ?? '').trim();
    return _shell(
      child: Column(
        children: [
          Container(
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
          ),
          const SizedBox(height: 24),
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
          if (_isSignedIn)
            const CircularProgressIndicator(color: albumTerracotta)
          else if (_requestId != null)
            SignInCodeForm(
              message:
                  'We sent a code to $_sentTo. Enter it to join $familyLabel.',
              messageKey: const Key('invite-sent'),
              signingIn: _signingIn,
              sending: _sending,
              error: _error,
              onSubmit: _signIn,
              onResend: _sendCode,
              onUseDifferentEmail: _useDifferentEmail,
            )
          else
            _form(),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) {
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

  Widget _form() {
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
        TextField(
          key: const Key('invite-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !_sending,
          onSubmitted: (_) => _sendCode(),
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
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: GoogleFonts.literata(color: albumTerracotta, fontSize: 14),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending ? null : _sendCode,
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            foregroundColor: _inviteOnPrimary,
            disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.55),
            disabledForegroundColor: _inviteOnPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sending ? sendingCodeLabel : sendCodeLabel,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _inviteOnPrimary,
                  ),
                ),
                if (!_sending) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          landingPasswordNote,
          textAlign: TextAlign.center,
          style: GoogleFonts.literata(color: _inviteOutline, fontSize: 12),
        ),
      ],
    );
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
}

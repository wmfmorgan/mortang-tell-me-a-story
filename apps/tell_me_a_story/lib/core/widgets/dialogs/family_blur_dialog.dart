import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// Shared sigma-4 scrim. Start-a-family keeps its own sigma-5 blur.
class FamilyBlurShell extends StatelessWidget {
  const FamilyBlurShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(color: albumInk.withAlpha(0x66), child: child),
    );
  }
}

/// Blur shell whose scrim runs [onDismiss] and whose centered [child]
/// swallows taps.
class _TapOutsideShell extends StatelessWidget {
  const _TapOutsideShell({required this.onDismiss, required this.child});

  final VoidCallback? onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FamilyBlurShell(
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(onTap: () {}, child: child),
        ),
      ),
    );
  }
}

/// The close X in a blur card's top-right corner. Must sit in a [Stack].
class CornerCloseButton extends StatelessWidget {
  const CornerCloseButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -12,
      right: -12,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close, size: 20),
        color: albumInk,
      ),
    );
  }
}

Widget _fade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(opacity: animation, child: child);

/// Full-viewport blur with a centered card. Dropdowns stay on their own routes.
///
/// [scopedMessages] gives the card its own [ScaffoldMessenger], so a SnackBar
/// it shows draws above the blur instead of under it on the page. Only for
/// cards that stay open after showing one: the SnackBar leaves with the card.
Future<T?> showBlurredCard<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool scopedMessages = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: albumBackdropClear,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final shell = _TapOutsideShell(
        onDismiss: barrierDismissible
            ? () => Navigator.pop(dialogContext)
            : null,
        child: builder(dialogContext),
      );
      if (!scopedMessages) return shell;
      return ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: albumBackdropClear,
          // The card pads for the keyboard itself.
          resizeToAvoidBottomInset: false,
          body: shell,
        ),
      );
    },
    transitionBuilder: _fade,
  );
}

/// Full-page blur confirm. Stitch `e37136c3a1734a30ac5487b42cd91f42`.
/// True only when the confirm button is pressed.
Future<bool> showFamilyBlurDialog(
  BuildContext context, {
  required Key dialogKey,
  required String title,
  String? body,
  required String confirmLabel,
  required Key confirmKey,
  required Color confirmColor,
  String cancelLabel = 'Cancel',
  Key? cancelKey,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: albumBackdropClear,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _FamilyBlurDialog(
        dialogKey: dialogKey,
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        confirmKey: confirmKey,
        confirmColor: confirmColor,
        cancelLabel: cancelLabel,
        cancelKey: cancelKey,
      );
    },
    transitionBuilder: _fade,
  );
  return confirmed == true;
}

class _FamilyBlurDialog extends StatelessWidget {
  const _FamilyBlurDialog({
    required this.dialogKey,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmKey,
    required this.confirmColor,
    required this.cancelLabel,
    required this.cancelKey,
  });

  final Key dialogKey;
  final String title;
  final String? body;
  final String confirmLabel;
  final Key confirmKey;
  final Color confirmColor;
  final String cancelLabel;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) {
    return _TapOutsideShell(
      onDismiss: () => Navigator.pop(context, false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          key: dialogKey,
          decoration: BoxDecoration(
            color: albumDialogSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: albumShadow.withAlpha(0x1A),
                blurRadius: 25,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Stack(
                children: [
                  _FamilyBlurDialogBody(dialog: this),
                  CornerCloseButton(
                    onPressed: () => Navigator.pop(context, false),
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

class _FamilyBlurDialogBody extends StatelessWidget {
  const _FamilyBlurDialogBody({required this.dialog});

  final _FamilyBlurDialog dialog;

  @override
  Widget build(BuildContext context) {
    final body = dialog.body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          dialog.title,
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.literata(
              color: albumInk,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _FamilyBlurDialogActions(dialog: dialog),
      ],
    );
  }
}

class _FamilyBlurDialogActions extends StatelessWidget {
  const _FamilyBlurDialogActions({required this.dialog});

  final _FamilyBlurDialog dialog;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final textStyle = GoogleFonts.sourceSans3(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 8,
      children: [
        TextButton(
          key: dialog.cancelKey,
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            foregroundColor: albumInk,
            padding: padding,
            shape: shape,
            textStyle: textStyle,
          ),
          child: Text(dialog.cancelLabel),
        ),
        FilledButton(
          key: dialog.confirmKey,
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: dialog.confirmColor,
            foregroundColor: albumWhite,
            elevation: 0,
            padding: padding,
            shape: shape,
            textStyle: textStyle,
          ),
          child: Text(dialog.confirmLabel),
        ),
      ],
    );
  }
}

/// Send-invite confirm. Stitch `b1fe8caf283040809781a10bba45c97c`.
/// True only when Send invite is pressed.
Future<bool> showSendInviteConfirm(
  BuildContext context, {
  required String name,
  required String email,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: albumBackdropClear,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _SendInviteConfirm(name: name, email: email);
    },
    transitionBuilder: _fade,
  );
  return confirmed == true;
}

final _inviteInkLight = albumInk.withValues(alpha: 0.62);

class _SendInviteConfirm extends StatelessWidget {
  const _SendInviteConfirm({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return _TapOutsideShell(
      onDismiss: () => Navigator.pop(context, false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          key: const Key('send-invite-confirm'),
          decoration: BoxDecoration(
            color: albumParchment,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: albumInviteBorder),
            boxShadow: [
              BoxShadow(
                color: albumInk.withAlpha(0x1A),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
              child: _SendInviteBody(name: name, email: email),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendInviteBody extends StatelessWidget {
  const _SendInviteBody({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SendInviteHeader(),
        const SizedBox(height: 8),
        Text(
          'Send invite to $name?',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _SendInviteMessage(email: email),
        const SizedBox(height: 16),
        const _SendInviteNote(),
        const SizedBox(height: 18),
        Divider(height: 1, color: albumInviteBorder.withAlpha(0x80)),
        const SizedBox(height: 14),
        const _SendInviteActions(),
      ],
    );
  }
}

class _SendInviteHeader extends StatelessWidget {
  const _SendInviteHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: albumSage.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: albumSage.withValues(alpha: 0.28)),
          ),
          child: const Icon(Icons.mail_outline, size: 20, color: albumSage),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Close',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.pop(context, false),
          icon: Icon(Icons.close, size: 18, color: _inviteInkLight),
        ),
      ],
    );
  }
}

class _SendInviteMessage extends StatelessWidget {
  const _SendInviteMessage({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.literata(
          color: _inviteInkLight,
          fontSize: 14,
          height: 1.45,
        ),
        children: [
          const TextSpan(text: "We'll send a private sign-in link to "),
          TextSpan(
            text: email,
            style: GoogleFonts.literata(
              color: albumInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const TextSpan(
            text: ' so they can read and contribute stories to the family archive.',
          ),
        ],
      ),
    );
  }
}

class _SendInviteNote extends StatelessWidget {
  const _SendInviteNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumInviteNoteFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: albumInviteBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 16, color: albumSage),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "They'll be added as a family member with immediate access to read shared memories.",
                style: GoogleFonts.sourceSans3(
                  color: _inviteInkLight,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendInviteActions extends StatelessWidget {
  const _SendInviteActions();

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final textStyle = GoogleFonts.sourceSans3(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          key: const Key('send-invite-confirm-no'),
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: albumSage,
            side: BorderSide(color: albumSage.withValues(alpha: 0.4)),
            padding: padding,
            shape: shape,
            textStyle: textStyle,
          ),
          child: const Text('Not now'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          key: const Key('send-invite-confirm-yes'),
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            foregroundColor: albumParchment,
            elevation: 0,
            padding: padding,
            shape: shape,
            textStyle: textStyle,
          ),
          child: const Text('Send invite'),
        ),
      ],
    );
  }
}

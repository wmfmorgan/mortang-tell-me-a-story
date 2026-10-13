import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';

/// Shared sigma-4 scrim. Start-a-family keeps its own sigma-5 blur.
Widget familyBlurShell({required Widget child}) {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
    child: ColoredBox(color: const Color(0x662C2416), child: child),
  );
}

/// Full-viewport blur with a centered card. Dropdowns stay on their own routes.
Future<T?> showBlurredCard<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return familyBlurShell(
        child: GestureDetector(
          onTap: barrierDismissible ? () => Navigator.pop(dialogContext) : null,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(onTap: () {}, child: builder(dialogContext)),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
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
    barrierColor: Colors.transparent,
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
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
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
    return familyBlurShell(
      child: GestureDetector(
        onTap: () => Navigator.pop(context, false),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                key: dialogKey,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 25,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
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
                                body!,
                                style: GoogleFonts.literata(
                                  color: albumInk,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                  key: cancelKey,
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: albumInk,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: GoogleFonts.sourceSans3(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: Text(cancelLabel),
                                ),
                                FilledButton(
                                  key: confirmKey,
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: confirmColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: GoogleFonts.sourceSans3(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: Text(confirmLabel),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: -12,
                          right: -12,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close, size: 20),
                            color: albumInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _SendInviteConfirm(name: name, email: email);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
  return confirmed == true;
}

class _SendInviteConfirm extends StatelessWidget {
  const _SendInviteConfirm({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final inkLight = albumInk.withValues(alpha: 0.62);
    return familyBlurShell(
      child: GestureDetector(
        onTap: () => Navigator.pop(context, false),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                key: const Key('send-invite-confirm'),
                decoration: BoxDecoration(
                  color: albumParchment,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8DFD5)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A2C2416),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: albumSage.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: albumSage.withValues(alpha: 0.28),
                                ),
                              ),
                              child: const Icon(
                                Icons.mail_outline,
                                size: 20,
                                color: albumSage,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Close',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.pop(context, false),
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: inkLight,
                              ),
                            ),
                          ],
                        ),
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
                        Text.rich(
                          TextSpan(
                            style: GoogleFonts.literata(
                              color: inkLight,
                              fontSize: 14,
                              height: 1.45,
                            ),
                            children: [
                              const TextSpan(
                                text: "We'll send a private sign-in link to ",
                              ),
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
                        ),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F1EA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE8DFD5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: albumSage,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "They'll be added as a family member with immediate access to read shared memories.",
                                    style: GoogleFonts.sourceSans3(
                                      color: inkLight,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1, color: Color(0x80E8DFD5)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              key: const Key('send-invite-confirm-no'),
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: albumSage,
                                side: BorderSide(
                                  color: albumSage.withValues(alpha: 0.4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: GoogleFonts.sourceSans3(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: GoogleFonts.sourceSans3(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Send invite'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

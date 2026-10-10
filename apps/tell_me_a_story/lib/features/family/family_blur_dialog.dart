import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';

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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(
        color: const Color(0x662C2416),
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
                                    color: const Color(0xFF655E5B),
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
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                              color: const Color(0xFF655E5B),
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
      ),
    );
  }
}

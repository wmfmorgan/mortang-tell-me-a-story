import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/family/family_blur_dialog.dart';
import '../theme/album_theme.dart';

const _leaveTitle = 'Leave this story?';
const _leaveBody = "You have changes that aren't saved.";
const _stayLabel = 'Stay';
const _discardLabel = 'Discard';
const _saveLabel = 'Save';

/// Save, Discard, or Stay. True means the caller may finish the exit.
///
/// A thrown [save] stays on the page. The page shows its own error when it
/// catches one; anything else still closes the dialog and stays.
Future<bool> showLeaveStoryDialog(
  BuildContext context, {
  String? switchToFamilyName,
  required Future<bool> Function() save,
  required VoidCallback discard,
}) async {
  final name = switchToFamilyName?.trim();
  final body = name == null || name.isEmpty
      ? _leaveBody
      : "$_leaveBody Save them before switching to $name?";
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: _stayLabel,
    barrierColor: albumBackdropClear,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _LeaveStoryDialog(body: body, save: save, discard: discard);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
  return result == true;
}

class _LeaveStoryDialog extends StatefulWidget {
  const _LeaveStoryDialog({
    required this.body,
    required this.save,
    required this.discard,
  });

  final String body;
  final Future<bool> Function() save;
  final VoidCallback discard;

  @override
  State<_LeaveStoryDialog> createState() => _LeaveStoryDialogState();
}

class _LeaveStoryDialogState extends State<_LeaveStoryDialog> {
  var _saving = false;

  void _stay() {
    if (_saving) return;
    Navigator.pop(context, false);
  }

  void _onDiscard() {
    if (_saving) return;
    widget.discard();
    Navigator.pop(context, true);
  }

  Future<void> _onSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    var ok = false;
    try {
      ok = await widget.save();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      ok = false;
    }
    if (!mounted) return;
    Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final stay = TextButton(
      onPressed: _saving ? null : _stay,
      style: TextButton.styleFrom(
        foregroundColor: albumInk,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: const Text(_stayLabel),
    );
    final discard = OutlinedButton(
      onPressed: _saving ? null : _onDiscard,
      style: OutlinedButton.styleFrom(
        foregroundColor: albumInk,
        side: const BorderSide(color: albumSage),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: const Text(_discardLabel),
    );
    final save = FilledButton(
      onPressed: _saving ? null : _onSave,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.4),
        disabledForegroundColor: albumParchment,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: const Text(_saveLabel),
    );
    final buttons = narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              save,
              const SizedBox(height: 8),
              discard,
              const SizedBox(height: 8),
              stay,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              stay,
              const SizedBox(width: 12),
              discard,
              const SizedBox(width: 12),
              save,
            ],
          );
    return PopScope(
      canPop: !_saving,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _stay},
        child: Focus(
          autofocus: true,
          child: familyBlurShell(
            child: GestureDetector(
              onTap: _stay,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: albumDialogSurface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: albumInk.withValues(alpha: 0.1),
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
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _leaveTitle,
                                    style: GoogleFonts.newsreader(
                                      color: albumInk,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.body,
                                    style: GoogleFonts.literata(
                                      color: albumInk,
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  buttons,
                                ],
                              ),
                              Positioned(
                                top: -12,
                                right: -12,
                                child: IconButton(
                                  onPressed: _saving ? null : _stay,
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
          ),
        ),
      ),
    );
  }
}

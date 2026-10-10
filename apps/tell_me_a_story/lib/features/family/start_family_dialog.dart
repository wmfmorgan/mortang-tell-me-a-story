import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/manage_families_api.dart';

/// Stitch `78ba55e6adf1449685fe9dadcc1ccdfc`. Returns the new family id.
Future<String?> showStartFamilyDialog(
  BuildContext context, {
  required ManageFamiliesGateway api,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StartFamilyDialog(api: api);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _StartFamilyDialog extends StatefulWidget {
  const _StartFamilyDialog({required this.api});

  final ManageFamiliesGateway api;

  @override
  State<_StartFamilyDialog> createState() => _StartFamilyDialogState();
}

class _StartFamilyDialogState extends State<_StartFamilyDialog> {
  final _name = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    if (_busy) return;
    Navigator.pop(context);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.api.createRootFamily(name);
      if (!mounted) return;
      Navigator.pop(context, id);
    } on ManageFamiliesException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Couldn\'t create the family. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _name.text.trim().isNotEmpty && !_busy;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: ColoredBox(
        color: const Color(0x662C2416),
        child: GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: DecoratedBox(
                  key: const Key('start-family-dialog'),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF7F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6DEC8)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E2C2416),
                        blurRadius: 60,
                        offset: Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    surfaceTintColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5DED6)
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF6B5B55)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.menu_book,
                                  size: 24,
                                  color: Color(0xFF6B5B55),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Start a family',
                                style: GoogleFonts.newsreader(
                                  color: albumInk,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.3,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a new root family archive. You become the owner.',
                                style: GoogleFonts.literata(
                                  color: const Color(0xFF635746),
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Text(
                                    'Family name',
                                    style: GoogleFonts.sourceSans3(
                                      color: albumInk,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Required',
                                    style: GoogleFonts.sourceSans3(
                                      color: const Color(0xFF655E5B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: const Key('start-family-name'),
                                controller: _name,
                                autofocus: true,
                                style: GoogleFonts.literata(
                                  color: albumInk,
                                  fontSize: 18,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'e.g. The Morgan Family',
                                  hintStyle: GoogleFonts.literata(
                                    color: const Color(0xFFB9B0AD),
                                    fontSize: 18,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  border: _border,
                                  enabledBorder: _border,
                                  focusedBorder: _border.copyWith(
                                    borderSide: const BorderSide(
                                      color: Color(0xFF6B5B55),
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "You'll land on this family's empty timeline after create.",
                                style: GoogleFonts.literata(
                                  color: const Color(0xFF655E5B),
                                  fontSize: 14,
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: GoogleFonts.sourceSans3(
                                    color: albumTerracotta,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: _busy ? null : _close,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: albumInk,
                                      side: const BorderSide(
                                        color: Color(0x80B9B0AD),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: GoogleFonts.sourceSans3(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 14),
                                  FilledButton(
                                    key: const Key('start-family-create'),
                                    onPressed: ready ? _create : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF6B5B55),
                                      foregroundColor: const Color(0xFFFFF6F3),
                                      disabledBackgroundColor: const Color(
                                        0xFF6B5B55,
                                      ).withValues(alpha: 0.4),
                                      disabledForegroundColor: const Color(
                                        0xFFFFF6F3,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: GoogleFonts.sourceSans3(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Create family'),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 16),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              onPressed: _busy ? null : _close,
                              icon: const Icon(Icons.close, size: 22),
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

const _border = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFFDDD4C4)),
);

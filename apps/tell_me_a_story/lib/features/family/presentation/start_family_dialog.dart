import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';

/// Stitch `78ba55e6adf1449685fe9dadcc1ccdfc`. Returns the new family id.
Future<String?> showStartFamilyDialog(BuildContext context) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _StartFamilyDialog();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _StartFamilyDialog extends ConsumerStatefulWidget {
  const _StartFamilyDialog();

  @override
  ConsumerState<_StartFamilyDialog> createState() => _StartFamilyDialogState();
}

class _StartFamilyDialogState extends ConsumerState<_StartFamilyDialog> {
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
      final id = await ref
          .read(manageFamiliesRepositoryProvider)
          .createRootFamily(name);
      if (!mounted) return;
      Navigator.pop(context, id);
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      // Non-app failures map to the generic copy shown under the field.
      _fail('Couldn\'t create the family. Try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _name.text.trim().isNotEmpty && !_busy;
    final error = _error;
    return _DialogFrame(
      onDismiss: _close,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Intro(),
          const SizedBox(height: 32),
          const _NameLabel(),
          const SizedBox(height: 8),
          _NameField(controller: _name, onChanged: () => setState(() {})),
          const SizedBox(height: 8),
          Text(
            "You'll land on this family's empty timeline after create.",
            style: GoogleFonts.literata(color: albumInk, fontSize: 14),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.sourceSans3(
                color: albumTerracotta,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Actions(
            onCancel: _busy ? null : _close,
            onCreate: ready ? _create : null,
          ),
        ],
      ),
    );
  }
}

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({required this.onDismiss, required this.child});

  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: ColoredBox(
        color: const Color(0x662C2416),
        child: GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: _DialogCard(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
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
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IntroBadge(),
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
          "Create a new standalone family that isn't associated with any of your existing families. You become the owner.",
          style: GoogleFonts.literata(
            color: const Color(0xFF635746),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _IntroBadge extends StatelessWidget {
  const _IntroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5DED6).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6B5B55).withValues(alpha: 0.2),
        ),
      ),
      child: const Icon(Icons.menu_book, size: 24, color: Color(0xFF6B5B55)),
    );
  }
}

class _NameLabel extends StatelessWidget {
  const _NameLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
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
          style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 12),
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('start-family-name'),
      controller: controller,
      autofocus: true,
      style: GoogleFonts.literata(color: albumInk, fontSize: 18),
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
          borderSide: const BorderSide(color: Color(0xFF6B5B55)),
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onCancel, required this.onCreate});

  final VoidCallback? onCancel;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.sourceSans3(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: albumInk,
            side: const BorderSide(color: Color(0x80B9B0AD)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: shape,
            textStyle: textStyle,
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 14),
        _CreateButton(onCreate: onCreate, shape: shape, textStyle: textStyle),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.onCreate,
    required this.shape,
    required this.textStyle,
  });

  final VoidCallback? onCreate;
  final OutlinedBorder shape;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('start-family-create'),
      onPressed: onCreate,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF6B5B55),
        foregroundColor: const Color(0xFFFFF6F3),
        disabledBackgroundColor: const Color(0xFF6B5B55).withValues(alpha: 0.4),
        disabledForegroundColor: const Color(0xFFFFF6F3),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: shape,
        textStyle: textStyle,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create family'),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    );
  }
}

const _border = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFFDDD4C4)),
);

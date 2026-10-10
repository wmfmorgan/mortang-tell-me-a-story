import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';

/// Stitch `505fa619379b4ca797208e8087ccf630`. True when the name matches.
Future<bool> showDeleteFamilyDialog(
  BuildContext context, {
  required String familyName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _DeleteFamilyDialog(familyName: familyName),
  );
  return confirmed ?? false;
}

class _DeleteFamilyDialog extends StatefulWidget {
  const _DeleteFamilyDialog({required this.familyName});

  final String familyName;

  @override
  State<_DeleteFamilyDialog> createState() => _DeleteFamilyDialogState();
}

class _DeleteFamilyDialogState extends State<_DeleteFamilyDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _typed.text.trim() == widget.familyName;
    return Dialog(
      key: const Key('delete-family-dialog'),
      backgroundColor: albumParchment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delete ${widget.familyName}?',
                      style: GoogleFonts.newsreader(
                        color: albumInk,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Hidden for 60 days, then permanently removed. Owner/co-owner can Recover from Manage families. Story tags stay if people are tagged elsewhere.',
                style: GoogleFonts.literata(color: albumInk, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Type ${widget.familyName} to confirm',
                style: GoogleFonts.sourceSans3(color: albumInk),
              ),
              TextField(
                key: const Key('delete-family-confirm'),
                controller: _typed,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('delete-family-submit'),
                    onPressed: matches
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: const Text('Confirm delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

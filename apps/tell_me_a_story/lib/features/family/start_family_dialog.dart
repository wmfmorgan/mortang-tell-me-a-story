import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/manage_families_api.dart';

/// Stitch `78ba55e6adf1449685fe9dadcc1ccdfc`. Returns the new family id.
Future<String?> showStartFamilyDialog(
  BuildContext context, {
  required ManageFamiliesGateway api,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _StartFamilyDialog(api: api),
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
    return Dialog(
      key: const Key('start-family-dialog'),
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
                      'Start a family',
                      style: GoogleFonts.newsreader(
                        color: albumInk,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Create a new root family archive. You become the owner.',
                style: GoogleFonts.literata(color: albumInk, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Family name',
                style: GoogleFonts.sourceSans3(
                  color: albumInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextField(
                key: const Key('start-family-name'),
                controller: _name,
                decoration: const InputDecoration(hintText: 'Required'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                "You'll land on this family's empty timeline after create.",
                style: GoogleFonts.sourceSans3(color: albumInk, fontSize: 13),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: albumTerracotta)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('start-family-create'),
                    onPressed: ready ? _create : null,
                    child: const Text('Create family'),
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

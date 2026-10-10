import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_avatar.dart';
import '../../data/families_api.dart';
import 'family_role.dart';

class TransferChoice {
  const TransferChoice({
    required this.newOwnerUserId,
    required this.formerOwnerBecomes,
  });

  final String newOwnerUserId;
  final String formerOwnerBecomes;
}

/// Stitch `5a400d28acc24b9eb8f17da6ac3074e9`. No accept step.
Future<TransferChoice?> showTransferOwnershipDialog(
  BuildContext context, {
  required String familyName,
  required List<FamilyPerson> coOwners,
}) {
  return showDialog<TransferChoice>(
    context: context,
    builder: (context) =>
        _TransferDialog(familyName: familyName, coOwners: coOwners),
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.familyName, required this.coOwners});

  final String familyName;
  final List<FamilyPerson> coOwners;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  String? _ownerId;
  String? _former;

  @override
  Widget build(BuildContext context) {
    final ready = _ownerId != null && _former != null;
    return Dialog(
      key: const Key('transfer-ownership-dialog'),
      backgroundColor: albumParchment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transfer ownership',
                      style: GoogleFonts.newsreader(
                        color: albumInk,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Choose a new owner for ${widget.familyName}.',
                style: GoogleFonts.literata(color: albumInk, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'New owner',
                style: GoogleFonts.sourceSans3(
                  color: albumInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              RadioGroup<String>(
                groupValue: _ownerId,
                onChanged: (value) => setState(() => _ownerId = value),
                child: Column(
                  children: [
                    for (final person in widget.coOwners)
                      RadioListTile<String>(
                        key: Key('transfer-owner-${person.userId}'),
                        value: person.userId,
                        title: Row(
                          children: [
                            ProfileAvatar(
                              size: 32,
                              displayName: person.displayName,
                              bytes: person.avatarBytes,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                person.displayName?.trim().isNotEmpty == true
                                    ? person.displayName!.trim()
                                    : 'Member',
                              ),
                            ),
                            const FamilyRoleChip(role: 'co_owner'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'After transfer, you become: ',
                  children: [
                    TextSpan(
                      text: '(required)',
                      style: GoogleFonts.sourceSans3(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: GoogleFonts.sourceSans3(color: albumInk),
              ),
              RadioGroup<String>(
                groupValue: _former,
                onChanged: (value) => setState(() => _former = value),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      key: const Key('transfer-become-co-owner'),
                      value: 'co_owner',
                      title: const Text('Co-owner'),
                      subtitle: const Text(
                        'Maintain full administrative editing rights and member management capabilities.',
                      ),
                    ),
                    RadioListTile<String>(
                      key: const Key('transfer-become-member'),
                      value: 'member',
                      title: const Text('Member'),
                      subtitle: const Text(
                        'Standard contributor access to view and add memories to the family archive.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('transfer-ownership-submit'),
                    onPressed: ready
                        ? () => Navigator.pop(
                            context,
                            TransferChoice(
                              newOwnerUserId: _ownerId!,
                              formerOwnerBecomes: _former!,
                            ),
                          )
                        : null,
                    child: const Text('Transfer ownership'),
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

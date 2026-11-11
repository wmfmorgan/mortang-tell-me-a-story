import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_avatar.dart';
import 'package:tell_me_a_story/core/widgets/dialogs/family_blur_dialog.dart';
import 'package:tell_me_a_story/core/widgets/family/family_role.dart';

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
  return showBlurredCard<TransferChoice>(
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

  VoidCallback? get _submit {
    if (_ownerId case final ownerId?) {
      if (_former case final former?) {
        return () => Navigator.pop(
          context,
          TransferChoice(newOwnerUserId: ownerId, formerOwnerBecomes: former),
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('transfer-ownership-dialog'),
      color: albumParchment,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(familyName: widget.familyName),
              const SizedBox(height: 16),
              _OwnerChoice(
                coOwners: widget.coOwners,
                ownerId: _ownerId,
                onChanged: (value) => setState(() => _ownerId = value),
              ),
              const SizedBox(height: 8),
              _FormerChoice(
                former: _former,
                onChanged: (value) => setState(() => _former = value),
              ),
              const SizedBox(height: 8),
              _Actions(onSubmit: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          'Choose a new owner for $familyName.',
          style: GoogleFonts.literata(color: albumInk, fontSize: 16),
        ),
      ],
    );
  }
}

class _OwnerChoice extends StatelessWidget {
  const _OwnerChoice({
    required this.coOwners,
    required this.ownerId,
    required this.onChanged,
  });

  final List<FamilyPerson> coOwners;
  final String? ownerId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New owner',
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        RadioGroup<String>(
          groupValue: ownerId,
          onChanged: onChanged,
          child: Column(
            children: [
              for (final person in coOwners)
                RadioListTile<String>(
                  key: Key('transfer-owner-${person.userId}'),
                  value: person.userId,
                  title: _CoOwnerLabel(person: person),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoOwnerLabel extends StatelessWidget {
  const _CoOwnerLabel({required this.person});

  final FamilyPerson person;

  @override
  Widget build(BuildContext context) {
    final name = person.displayName?.trim() ?? '';
    return Row(
      children: [
        ProfileAvatar(
          size: 32,
          displayName: person.displayName,
          bytes: person.avatarBytes,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name.isNotEmpty ? name : 'Member')),
        const FamilyRoleChip(role: 'co_owner'),
      ],
    );
  }
}

class _FormerChoice extends StatelessWidget {
  const _FormerChoice({required this.former, required this.onChanged});

  final String? former;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'After transfer, you become: ',
            children: [
              TextSpan(
                text: '(required)',
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          style: GoogleFonts.sourceSans3(color: albumInk),
        ),
        RadioGroup<String>(
          groupValue: former,
          onChanged: onChanged,
          child: const _FormerOptions(),
        ),
      ],
    );
  }
}

class _FormerOptions extends StatelessWidget {
  const _FormerOptions();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        RadioListTile<String>(
          key: Key('transfer-become-co-owner'),
          value: 'co_owner',
          title: Text('Co-owner'),
          subtitle: Text(
            'Maintain full administrative editing rights and member management capabilities.',
          ),
        ),
        RadioListTile<String>(
          key: Key('transfer-become-member'),
          value: 'member',
          title: Text('Member'),
          subtitle: Text(
            'Standard contributor access to view and add memories to the family archive.',
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onSubmit});

  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('transfer-ownership-submit'),
          onPressed: onSubmit,
          child: const Text('Transfer ownership'),
        ),
      ],
    );
  }
}

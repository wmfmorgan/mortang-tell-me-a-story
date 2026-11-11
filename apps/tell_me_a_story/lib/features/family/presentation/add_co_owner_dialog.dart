import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_initials.dart';

/// Stitch `71ccb38d05c54f75b6c830e480b06bc0`. Returns the chosen member id.
Future<String?> showAddCoOwnerDialog(
  BuildContext context, {
  required String familyName,
  required int coOwnerCount,
  required List<FamilyPerson> members,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AddCoOwnerDialog(
        familyName: familyName,
        coOwnerCount: coOwnerCount,
        members: members,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _AddCoOwnerDialog extends StatefulWidget {
  const _AddCoOwnerDialog({
    required this.familyName,
    required this.coOwnerCount,
    required this.members,
  });

  final String familyName;
  final int coOwnerCount;
  final List<FamilyPerson> members;

  @override
  State<_AddCoOwnerDialog> createState() => _AddCoOwnerDialogState();
}

class _AddCoOwnerDialogState extends State<_AddCoOwnerDialog> {
  final _search = TextEditingController();
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _close() => Navigator.pop(context);

  List<FamilyPerson> get _candidates => [
    for (final person in widget.members)
      if (person.role == 'member') person,
  ];

  List<FamilyPerson> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _candidates;
    return [
      for (final person in _candidates)
        if (_label(person).toLowerCase().contains(query)) person,
    ];
  }

  void _confirm() {
    final id = _selectedId;
    if (id == null) return;
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      onClose: _close,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Intro(
            familyName: widget.familyName,
            used: widget.coOwnerCount.clamp(0, 2),
          ),
          const SizedBox(height: 12),
          _SearchField(controller: _search, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _CandidateList(
            people: _visible,
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
          ),
          const SizedBox(height: 16),
          Text(
            'Only people already in this family can be co-owners. To add someone new, invite them first.',
            style: GoogleFonts.sourceSans3(
              color: albumInk,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _Actions(
            onCancel: _close,
            onConfirm: _selectedId == null ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

/// Blurred scrim, tap-outside close, and the card with its close button.
class _DialogFrame extends StatelessWidget {
  const _DialogFrame({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(
        color: const Color(0x662C2416),
        child: GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 512,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                child: _DialogCard(onClose: onClose, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogCard extends StatelessWidget {
  const _DialogCard({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('add-co-owner-dialog'),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB9B0AD).withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 25,
            offset: Offset(0, 20),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Stack(
            children: [
              child,
              Positioned(top: -8, right: -8, child: _CloseButton(onClose)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton(this.onClose);

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('add-co-owner-close'),
      onPressed: onClose,
      icon: const Icon(Icons.close, size: 20),
      color: albumInk,
      style: IconButton.styleFrom(
        fixedSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.familyName, required this.used});

  final String familyName;
  final int used;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add a co-owner',
          style: GoogleFonts.newsreader(
            color: albumInk,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Co-owners have the same powers as you. $familyName can have up to two.',
          style: GoogleFonts.literata(
            color: albumInk,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '$used OF 2 CO-OWNER SPOTS USED',
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('add-co-owner-search'),
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.literata(color: albumInk, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: albumParchment,
        hintText: 'Search members',
        hintStyle: GoogleFonts.literata(color: albumInk, fontSize: 14),
        prefixIcon: const Icon(Icons.search, size: 18, color: albumInk),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: _searchBorder,
        enabledBorder: _searchBorder,
        focusedBorder: _searchBorder.copyWith(
          borderSide: const BorderSide(color: albumTerracotta),
        ),
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.people,
    required this.selectedId,
    required this.onSelect,
  });

  final List<FamilyPerson> people;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x33B9B0AD)),
          bottom: BorderSide(color: Color(0x33B9B0AD)),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: people.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, thickness: 1, color: Color(0x33B9B0AD)),
          itemBuilder: (context, index) {
            final person = people[index];
            return _MemberRow(
              person: person,
              selected: person.userId == selectedId,
              onTap: () => onSelect(person.userId),
            );
          },
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    final textStyle = GoogleFonts.sourceSans3(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: albumInk,
            padding: padding,
            shape: shape,
            textStyle: textStyle,
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          key: const Key('add-co-owner-submit'),
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: albumTerracotta,
            foregroundColor: const Color(0xFFFFF6F3),
            disabledBackgroundColor: albumTerracotta.withValues(alpha: 0.4),
            disabledForegroundColor: const Color(0xFFFFF6F3),
            elevation: 0,
            padding: padding,
            shape: shape,
            textStyle: textStyle,
          ),
          child: const Text('Make co-owner'),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final FamilyPerson person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _label(person);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: selected
            ? const Color(0xFFF5DED6).withValues(alpha: 0.3)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? albumTerracotta.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          key: Key('add-co-owner-${person.userId}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _InitialsMark(label: label),
                const SizedBox(width: 14),
                Expanded(child: _MemberText(label: label)),
                _SelectDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsMark extends StatelessWidget {
  const _InitialsMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF0E6E3),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(label),
        style: GoogleFonts.newsreader(
          color: albumInk,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MemberText extends StatelessWidget {
  const _MemberText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.literata(
            color: albumInk,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        Text(
          'Member',
          style: GoogleFonts.sourceSans3(
            color: albumInk,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? albumTerracotta : Colors.transparent,
        shape: BoxShape.circle,
        border: selected ? null : Border.all(color: const Color(0xFFB9B0AD)),
      ),
      child: selected
          ? const Icon(Icons.check, size: 12, color: Color(0xFFFFF6F3))
          : null,
    );
  }
}

String _label(FamilyPerson person) {
  final name = person.displayName?.trim() ?? '';
  return name.isEmpty ? 'Member' : name;
}

String _initials(String name) {
  final letters = profileInitials(name);
  if (letters.isEmpty) return '?';
  if (letters.length <= 2) return letters;
  return '${letters[0]}${letters[letters.length - 1]}';
}

const _searchBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0x66B9B0AD)),
);

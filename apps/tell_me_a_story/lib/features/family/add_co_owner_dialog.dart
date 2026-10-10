import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../core/theme/profile_initials.dart';
import '../../data/families_api.dart';

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

  List<FamilyPerson> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.members;
    return [
      for (final person in widget.members)
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
    final visible = _visible;
    final used = widget.coOwnerCount.clamp(0, 2);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: ColoredBox(
        color: const Color(0x662C2416),
        child: GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 512,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                child: DecoratedBox(
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
                          Column(
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
                                'Co-owners have the same powers as you. ${widget.familyName} can have up to two.',
                                style: GoogleFonts.literata(
                                  color: const Color(0xFF655E5B),
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '$used OF 2 CO-OWNER SPOTS USED',
                                style: GoogleFonts.sourceSans3(
                                  color: const Color(0xFF655E5B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: const Key('add-co-owner-search'),
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.literata(
                                  color: albumInk,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFFAF2F0),
                                  hintText: 'Search members',
                                  hintStyle: GoogleFonts.literata(
                                    color: const Color(0xFF655E5B),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                    color: Color(0xFF655E5B),
                                  ),
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
                                    borderSide: const BorderSide(
                                      color: albumTerracotta,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Color(0x33B9B0AD)),
                                    bottom: BorderSide(
                                      color: Color(0x33B9B0AD),
                                    ),
                                  ),
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: visible.length,
                                    separatorBuilder: (_, _) => const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0x33B9B0AD),
                                    ),
                                    itemBuilder: (context, index) {
                                      final person = visible[index];
                                      final selected =
                                          person.userId == _selectedId;
                                      return _MemberRow(
                                        person: person,
                                        selected: selected,
                                        onTap: () => setState(
                                          () => _selectedId = person.userId,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Only people already in this family can be co-owners. To add someone new, invite them first.',
                                style: GoogleFonts.sourceSans3(
                                  color: const Color(0xFF655E5B),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: _close,
                                    style: TextButton.styleFrom(
                                      foregroundColor: albumInk,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
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
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    key: const Key('add-co-owner-submit'),
                                    onPressed: _selectedId == null
                                        ? null
                                        : _confirm,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: albumTerracotta,
                                      foregroundColor: const Color(0xFFFFF6F3),
                                      disabledBackgroundColor: albumTerracotta
                                          .withValues(alpha: 0.4),
                                      disabledForegroundColor: const Color(
                                        0xFFFFF6F3,
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
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
                                    child: const Text('Make co-owner'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              onPressed: _close,
                              icon: const Icon(Icons.close, size: 20),
                              color: const Color(0xFF655E5B),
                              style: IconButton.styleFrom(
                                fixedSize: const Size(32, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
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
                Container(
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
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
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
                          color: const Color(0xFF655E5B),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? albumTerracotta : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected
                        ? null
                        : Border.all(color: const Color(0xFFB9B0AD)),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Color(0xFFFFF6F3),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
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

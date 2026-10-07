import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';

String familyRoleLabel(String role) {
  return switch (role) {
    'owner' => 'Owner',
    'co_owner' => 'Co-owner',
    _ => 'Member',
  };
}

class FamilyRoleChip extends StatelessWidget {
  const FamilyRoleChip({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final owner = role == 'owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: owner ? albumTerracotta : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: owner ? albumTerracotta : albumSage),
      ),
      child: Text(
        familyRoleLabel(role),
        style: GoogleFonts.sourceSans3(
          color: owner ? albumParchment : albumInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String deletedRecoveryLine(DateTime deletedAt) {
  final days = DateTime.now().toUtc().difference(deletedAt.toUtc()).inDays;
  final n = days < 0 ? 0 : days;
  final remain = 60 - n;
  final left = remain < 0 ? 0 : remain;
  return 'deleted $n days ago · Available for recovery for $left more days';
}

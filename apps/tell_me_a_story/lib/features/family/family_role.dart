import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';

/// First letter of [name], skipping a leading "The ", uppercased.
String familyMonogram(String name) {
  var trimmed = name.trim();
  if (trimmed.length >= 4 && trimmed.substring(0, 4).toLowerCase() == 'the ') {
    trimmed = trimmed.substring(4).trim();
  }
  if (trimmed.isEmpty) return '';
  return trimmed[0].toUpperCase();
}

/// Parchment circle with [familyMonogram].
class FamilyMonogram extends StatelessWidget {
  const FamilyMonogram({super.key, required this.name, this.size = 28});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: albumParchment,
        shape: BoxShape.circle,
        border: Border.all(color: albumInk.withValues(alpha: 0.12)),
      ),
      child: Text(
        familyMonogram(name),
        style: GoogleFonts.newsreader(
          color: albumInk,
          fontSize: size * 0.46,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

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

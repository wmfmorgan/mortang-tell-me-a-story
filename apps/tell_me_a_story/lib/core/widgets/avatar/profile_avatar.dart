import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/avatar/profile_initials.dart';

/// Signed-in circle. A picture fills it. Initials show only when there is
/// no picture and the saved name has words.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    required this.displayName,
    this.bytes,
  });

  final double size;
  final String? displayName;
  final Uint8List? bytes;

  static const fill = albumAvatarFill;
  static const borderColor = albumAvatarBorder;

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    final hasImage = image != null && image.isNotEmpty;
    final initials = hasImage ? '' : profileInitials(displayName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image != null && hasImage
          ? Image.memory(
              image,
              key: const Key('profile-avatar-image'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : initials.isEmpty
          ? const SizedBox.shrink()
          : Text(
              initials,
              style: GoogleFonts.sourceSans3(
                color: albumInk,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

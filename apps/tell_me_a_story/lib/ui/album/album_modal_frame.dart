import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// Card, scrim, and icon label shared by the reader and the capture form.
class AlbumModalFrame extends StatelessWidget {
  const AlbumModalFrame({
    super.key,
    required this.frameKey,
    required this.label,
    required this.trailing,
    required this.child,
    this.markKey,
    this.showScrim = true,
  });

  final Key frameKey;
  final Key? markKey;
  final String label;
  final Widget trailing;
  final Widget child;
  final bool showScrim;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (showScrim)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const ColoredBox(color: albumModalScrim),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1040,
                  maxHeight: height - 48,
                ),
                child: Material(
                  key: frameKey,
                  color: albumParchment,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: albumModalBorder),
                  ),
                  child: Scaffold(
                    backgroundColor: albumParchment,
                    body: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                key: markKey,
                                color: albumTerracotta,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: albumSage,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: trailing,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

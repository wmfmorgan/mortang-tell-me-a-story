import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.line});

  final String line;

  static const designHeight = 56.0;

  static String firstLine(String? body) {
    final raw = body?.trim() ?? '';
    if (raw.isEmpty) return '';
    return raw.split('\n').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('quote-card'),
      width: 200,
      height: designHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(albumCardRadius),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Text('“', style: _mark),
            const SizedBox(width: 4),
            Expanded(child: _line(context)),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context) {
    if (line.isEmpty) return const SizedBox.shrink();
    return Text(
      line,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

final _mark = GoogleFonts.newsreader(
  color: albumTerracotta,
  fontSize: 48,
  height: 1,
  fontWeight: FontWeight.w600,
);

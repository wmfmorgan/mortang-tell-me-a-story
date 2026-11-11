part of 'album_header.dart';

/// Widths for one bar. [loose] is the unscaled row that [FittedBox] shrinks.
class _HeaderMetrics {
  const _HeaderMetrics({
    required this.page,
    required this.pad,
    required this.word,
    required this.family,
    required this.search,
    required this.gaps,
    required this.loose,
    this.captureStatus,
  });

  final AlbumHeaderPage page;
  final double pad;
  final double word;
  final double family;
  final double search;
  final List<double> gaps;
  final bool loose;
  final String? captureStatus;

  static const _searchHit = 40.0;
  static const _familyChrome = 47.5;
  static const _familyMin = 46.0;
  static const _padMax = 32.0;

  static _HeaderMetrics of({
    required AlbumHeaderPage page,
    required String familyName,
    required List<double> gaps,
    String? captureStatus,
  }) {
    return _HeaderMetrics(
      page: page,
      pad: _padMax,
      word: _textWidth('Tell Me a Story', _wordStyle),
      family: _textWidth(familyName, _familyStyle) + _familyChrome,
      search: page == AlbumHeaderPage.capture ? _searchHit : 0,
      gaps: gaps,
      loose: true,
      captureStatus: captureStatus,
    );
  }

  /// Width of the pieces that stay full size: hairline, Home, nav labels,
  /// and the action cluster. Wordmark, padding, gaps, and the family slot
  /// absorb a narrower window until this floor, then the bar scales.
  double get inflexibleFloor => _rigidWidth() + 8;

  /// Fits [viewport] by shrinking the wordmark, then padding and gaps.
  /// The family name is a flex child: it takes the leftover left of the
  /// right cluster and ellipsizes on one line. The search hit target stays.
  _HeaderMetrics fit(double viewport) {
    var pad = this.pad;
    var word = this.word;
    var gaps = [...this.gaps];
    // Button chrome is a pixel or two wider than the text-plus-padding
    // estimate. Keep that slack in the budget so the row does not overflow.
    final rigid = _rigidWidth() + 4;

    double used() =>
        pad * 2 +
        word +
        _familyMin +
        search +
        rigid +
        gaps.fold(0, (a, b) => a + b);

    var overflow = used() - viewport;
    if (overflow > 0) {
      final cut = overflow < word ? overflow : word;
      word -= cut;
      overflow -= cut;
    }
    if (overflow > 0 && pad > 0) {
      final cut = overflow / 2 < pad ? overflow / 2 : pad;
      pad -= cut;
      overflow -= cut * 2;
    }
    if (overflow > 0) gaps = _shrinkGaps(gaps, overflow);
    return _HeaderMetrics(
      page: page,
      pad: pad,
      word: word,
      family: _familyMin,
      search: search,
      gaps: gaps,
      loose: false,
      captureStatus: captureStatus,
    );
  }

  static List<double> _shrinkGaps(List<double> gaps, double overflow) {
    final sum = gaps.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return gaps;
    final factor = sum > overflow ? (sum - overflow) / sum : 0.0;
    return [for (final gap in gaps) gap * factor];
  }

  double _rigidWidth() {
    // Hairline plus Home, the nav labels, and the action buttons. Those stay
    // put while the wordmark, padding, gaps, and family name absorb a
    // narrower window.
    final home = _homeWidth();
    final decades = _textWidth('Timeline', _navStyle) + _navPadH * 2;
    final timeline = _textWidth('Stories', _navStyle) + _navPadH * 2;
    final drafts = _textWidth('Draft Stories', _navStyle) + _navPadH * 2;
    return 1 + home + decades + timeline + drafts + _actionsWidth();
  }

  double _actionsWidth() {
    if (page == AlbumHeaderPage.capture) return _captureActionsWidth();
    return _searchHit +
        _HeaderBar._clusterGap +
        _textWidth(
          'New story',
          GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w500),
        ) +
        // Plus circle 20, its 6px gap, and 16px of horizontal padding each side.
        58 +
        _avatarSlot;
  }

  /// Keep this in sync with the capture buttons in [_CaptureActions].
  double _captureActionsWidth() {
    final status = captureStatus;
    final statusWidth = status == null
        ? 0.0
        : _textWidth(
                status,
                GoogleFonts.sourceSans3(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ) +
              12;
    return statusWidth +
        _textWidth(
          'Save draft',
          GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w600),
        ) +
        40 +
        12 +
        _textWidth(
          'Publish story',
          GoogleFonts.sourceSans3(fontSize: 14, fontWeight: FontWeight.w600),
        ) +
        40 +
        _avatarSlot;
  }

  /// Gap plus the 32px circle. Both action clusters end with the avatar.
  static const _avatarSlot = 44.0;

  static final TextStyle _wordStyle = GoogleFonts.newsreader(
    fontSize: 24,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
  );
  static final TextStyle _familyStyle = GoogleFonts.newsreader(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _navStyle = GoogleFonts.sourceSans3(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Horizontal padding on Home and each nav label. Shared with [_rigidWidth].
const _navPadH = 2.0;

/// [_HomeNav] icon. The tap target is [_homeHit], not this size.
const _homeIconSize = 26.0;

/// Home tap target. Shared with [_homeWidth].
const _homeHit = 44.0;

/// Home is an icon button. Its width is the 44px target, not the glyph.
double _homeWidth() => _homeHit;

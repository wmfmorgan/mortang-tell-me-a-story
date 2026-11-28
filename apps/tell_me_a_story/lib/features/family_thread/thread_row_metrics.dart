import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/family_thread_density.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'card_chip_layout.dart';
import 'quote_card.dart';
import 'thread_beat.dart';
import 'thread_center.dart';
import 'thread_rows.dart';

const threadLandmarkRowExtent = 56.0;
const threadOverviewUnfocusedExtent = 104.0;
const threadOverviewFocusedExtent = 148.0;
const threadBrowseOneLineExtent = 88.0;
const threadBrowseTwoLineExtent = 96.0;
const threadNonMatchingExtent = 44.0;
const threadAlternatingMin = 720.0;
const threadColumnWideMin = 600.0;
const threadBandLane = 76.0;
const threadSideGap = 24.0;
const threadOuterMargin = 16.0;
const threadContentLead = 72.0;
const threadPhoneTail = 16.0;
const threadWideTail = 24.0;
const threadMosaicUnfocused = 96.0;
const threadMosaicUnfocusedSingle = 80.0;
const threadMosaicFocused = 112.0;
const threadMosaicFocusedSingle = 96.0;
const threadMedallion = 64.0;
const threadMedallionGap = 12.0;
const threadBrowseCardMin = 280.0;
const threadBrowseCardMax = 360.0;
const threadCompactCardMin = 280.0;
const threadCompactCardMax = 400.0;
const threadExpandedCardMin = 320.0;
const threadExpandedCardMax = 560.0;
const threadExpandedWidthInset = 48.0;
const threadAreaCap = 48.0;
const threadBrowseFocusPad = 32.0;
const threadCompactRowPad = 24.0;
const threadExpandedRowPad = 64.0;
const threadExpandedLead = 32.0;
const threadExpandedTopInset = 24.0;
const threadBodyPad = 16.0;
const threadExpandedPad = 24.0;
const threadExpandedPadSingle = 16.0;
const threadAfterPhoto = 16.0;
const threadDateGap = 4.0;
const threadBeforeDivider = 12.0;
const threadDivider = 1.0;
const threadFooter = 44.0;
const threadPhotoMin = 160.0;
const threadFanBoxExtra = 48.0;
const threadFanMax = 400.0;
const threadFanMin = 200.0;
const threadPhotoCapFraction = 0.45;
const threadBrowseTitle = 24.0;
const threadBrowseTitleHeight = 1.2;
const threadBrowseTitleLines = 3;
const threadPlainTitle = 18.0;
const threadPlainTitleLines = 2;
const threadCompactTitle = 20.0;
const threadCompactTitleLines = 2;
const threadExpandedTitle = 28.0;
const threadExpandedTitleSingle = 24.0;
const threadExpandedTitleLines = 3;
const threadExcerpt = 15.0;
const threadExcerptHeight = 1.5;
const threadExcerptLines = 3;
const threadExcerptLinesShrunk = 2;
const threadQuoteMark = 32.0;
const threadCompactQuote = 14.0;
const threadLandmarkFont = 28.0;
const threadDateSize = 12.0;
const threadChipLabel = 13.0;

enum ThreadLayoutMode { alternating, singleSide }

ThreadLayoutMode threadLayoutMode(double width) => width >= threadAlternatingMin
    ? ThreadLayoutMode.alternating
    : ThreadLayoutMode.singleSide;

double threadSideColumn(double width) =>
    (width - threadBandLane) / 2 - threadSideGap - threadOuterMargin;

double threadSingleSideColumn(double width) =>
    width -
    threadContentLead -
    (width >= threadColumnWideMin ? threadWideTail : threadPhoneTail);

double threadContentColumn(double width) =>
    threadLayoutMode(width) == ThreadLayoutMode.singleSide
    ? threadSingleSideColumn(width)
    : threadSideColumn(width);

bool threadRowTopAligns({
  required FamilyThreadDensity density,
  required bool focused,
  required bool matches,
  required double rowExtent,
  required double threadHeight,
}) {
  if (density != FamilyThreadDensity.read || !focused || !matches) {
    return false;
  }
  return rowExtent > threadHeight + (threadExpandedRowPad - threadAreaCap);
}

double threadRowExtent({
  required ThreadBeat beat,
  required FamilyThreadDensity density,
  required bool focused,
  required double width,
  required TextScaler textScaler,
  required bool matches,
  required double threadHeight,
}) {
  final measure = _Measure();
  if (!matches) return _nonMatching(beat, width, textScaler, measure);
  return switch (density) {
    FamilyThreadDensity.overview => _overview(
      beat,
      focused,
      width,
      textScaler,
      measure,
    ),
    FamilyThreadDensity.browse => _browse(
      beat,
      focused,
      width,
      textScaler,
      measure,
    ),
    FamilyThreadDensity.read => _read(
      beat,
      focused,
      width,
      threadHeight,
      textScaler,
      measure,
    ),
  };
}

double threadCardHeight({
  required ThreadBeat beat,
  required FamilyThreadDensity density,
  required bool focused,
  required double width,
  required TextScaler textScaler,
  required double threadHeight,
}) {
  final story = _first(beat);
  if (story == null) return 0;
  final measure = _Measure();
  if (density == FamilyThreadDensity.read) {
    return focused
        ? _expandedCard(story, width, threadHeight, textScaler, measure)
        : _compactCard(story, width, textScaler, measure);
  }
  return _browseCard(_year(beat), story, width, textScaler, measure);
}

double threadLandmarkExtent(TextScaler textScaler) {
  final text = _Measure().height(
    '1990s',
    _news(threadLandmarkFont, fontStyle: FontStyle.italic),
    400,
    1,
    textScaler,
  );
  return text > threadLandmarkRowExtent ? text : threadLandmarkRowExtent;
}

({List<double> extents, List<double> offsets}) threadExtentTable({
  required List<ThreadRow> rows,
  required FamilyThreadDensity density,
  required int focusIndex,
  required double width,
  required double threadHeight,
  required TextScaler textScaler,
  required ThreadRowExtentCache cache,
  ThreadBeat Function(ThreadBeat beat)? measureBeat,
}) {
  final adapt = measureBeat ?? _sameBeat;
  final extents = List<double>.filled(rows.length, 0);
  for (var i = 0; i < rows.length; i++) {
    extents[i] = _rowExtent(
      rows[i],
      i == focusIndex,
      density,
      width,
      threadHeight,
      textScaler,
      cache,
      adapt,
    );
  }
  return (extents: extents, offsets: ThreadCenter.prefixSums(extents));
}

class ThreadRowExtentCache {
  final _values = <_ExtentKey, double>{};
  var misses = 0;

  double extent({
    required ThreadBeat beat,
    required FamilyThreadDensity density,
    required bool focused,
    required double width,
    required TextScaler textScaler,
    required bool matches,
    required double threadHeight,
  }) {
    final key = _ExtentKey(
      beat: _beatKey(beat),
      density: density.index,
      focused: focused,
      matches: matches,
      width: width,
      threadHeight: threadHeight,
      scale: textScaler.scale(1),
    );
    final hit = _values[key];
    if (hit != null) return hit;
    misses += 1;
    final value = threadRowExtent(
      beat: beat,
      density: density,
      focused: focused,
      width: width,
      textScaler: textScaler,
      matches: matches,
      threadHeight: threadHeight,
    );
    _values[key] = value;
    return value;
  }

  void clear() => _values.clear();
}

double _rowExtent(
  ThreadRow row,
  bool focused,
  FamilyThreadDensity density,
  double width,
  double threadHeight,
  TextScaler textScaler,
  ThreadRowExtentCache cache,
  ThreadBeat Function(ThreadBeat beat) adapt,
) {
  return switch (row) {
    ThreadLandmarkRow() => threadLandmarkExtent(textScaler),
    ThreadBeatRow(:final beat, :final matches) => cache.extent(
      beat: adapt(beat),
      density: density,
      focused: focused,
      width: width,
      textScaler: textScaler,
      matches: matches,
      threadHeight: threadHeight,
    ),
  };
}

double _browse(
  ThreadBeat beat,
  bool focused,
  double width,
  TextScaler scaler,
  _Measure measure,
) {
  final year = _year(beat);
  if (!focused) return _browsePlain(year, width, scaler, measure);
  final story = year.stories.isEmpty ? null : year.stories.first;
  if (story == null) return threadBrowseOneLineExtent + threadBrowseFocusPad;
  return _browseCard(year, story, width, scaler, measure) +
      threadBrowseFocusPad;
}

double _read(
  ThreadBeat beat,
  bool focused,
  double width,
  double threadHeight,
  TextScaler scaler,
  _Measure measure,
) {
  final story = _first(beat);
  if (story == null)
    return focused ? threadExpandedRowPad : threadCompactRowPad;
  if (!focused) {
    return _compactCard(story, width, scaler, measure) + threadCompactRowPad;
  }
  return _expandedCard(story, width, threadHeight, scaler, measure) +
      threadExpandedRowPad;
}

double _nonMatching(
  ThreadBeat beat,
  double width,
  TextScaler scaler,
  _Measure measure,
) {
  final story = _first(beat);
  final title = story == null ? '' : _title(story);
  final text = measure.height(
    title,
    _news(threadPlainTitle),
    threadContentColumn(width) - 20,
    1,
    scaler,
  );
  return text > threadNonMatchingExtent ? text : threadNonMatchingExtent;
}

double _overview(
  ThreadBeat beat,
  bool focused,
  double width,
  TextScaler scaler,
  _Measure measure,
) {
  final single = _single(width);
  final mosaic = focused
      ? (single ? threadMosaicFocusedSingle : threadMosaicFocused)
      : (single ? threadMosaicUnfocusedSingle : threadMosaicUnfocused);
  final min = focused
      ? threadOverviewFocusedExtent
      : threadOverviewUnfocusedExtent;
  if (beat is! DecadeBeat) return _max(min, mosaic);
  return _max(
    min,
    _max(mosaic, _overviewText(beat, focused, width, scaler, measure, mosaic)),
  );
}

double _overviewText(
  DecadeBeat beat,
  bool focused,
  double width,
  TextScaler scaler,
  _Measure measure,
  double mosaic,
) {
  final single = _single(width);
  final size = focused ? (single ? 32.0 : 36.0) : (single ? 28.0 : 32.0);
  final textW = threadContentColumn(width) - mosaic - threadBodyPad;
  final label = measure.height(
    '${beat.decadeStart}s',
    _news(size, weight: focused ? FontWeight.w700 : FontWeight.w400),
    textW,
    1,
    scaler,
  );
  final count = measure.height(
    'stories',
    _sans(threadChipLabel),
    textW,
    1,
    scaler,
  );
  return label + count + (focused ? _target(scaler) : 0);
}

double _browsePlain(
  YearBeat year,
  double width,
  TextScaler scaler,
  _Measure measure,
) {
  final story = year.stories.isEmpty ? null : year.stories.first;
  final title = story == null ? '' : _title(story);
  final textW =
      threadContentColumn(width) - threadMedallion - threadMedallionGap;
  final style = _news(threadPlainTitle);
  final lines = measure.lines(
    title,
    style,
    textW,
    threadPlainTitleLines,
    scaler,
  );
  final min = lines >= 2
      ? threadBrowseTwoLineExtent
      : threadBrowseOneLineExtent;
  final block =
      measure.height(title, style, textW, threadPlainTitleLines, scaler) +
      measure.height('·', _sans(threadDateSize), textW, 1, scaler);
  return _max(min, _max(threadMedallion, block));
}

double _browseCard(
  YearBeat year,
  Story story,
  double width,
  TextScaler scaler,
  _Measure measure,
) {
  final cardW = _cardWidth(width, threadBrowseCardMin, threadBrowseCardMax);
  final textW = cardW - threadBodyPad * 2;
  final more = year.stories.length > 1 ? _target(scaler) : 0.0;
  return cardW * 0.75 +
      threadBodyPad +
      _date(story, textW, scaler, measure, FontWeight.w700) +
      threadDateGap +
      measure.height(
        _title(story),
        _news(threadBrowseTitle, height: threadBrowseTitleHeight),
        textW,
        threadBrowseTitleLines,
        scaler,
      ) +
      _chips(story, textW, scaler, 2) +
      more +
      threadBeforeDivider +
      threadDivider +
      _target(scaler) +
      threadBodyPad;
}

double _compactCard(
  Story story,
  double width,
  TextScaler scaler,
  _Measure measure,
) {
  final cardW = _cardWidth(width, threadCompactCardMin, threadCompactCardMax);
  final textW = cardW - threadBodyPad * 2;
  final art = story.photoPaths.isEmpty
      ? _quote(story, textW, scaler, measure)
      : cardW * 0.5;
  return art +
      threadBodyPad +
      _date(story, textW, scaler, measure, FontWeight.w400) +
      threadDateGap +
      measure.height(
        _title(story),
        _news(threadCompactTitle),
        textW,
        threadCompactTitleLines,
        scaler,
      ) +
      _chips(story, textW, scaler, 1) +
      threadBeforeDivider +
      threadDivider +
      _target(scaler) +
      threadBodyPad;
}

double _expandedCard(
  Story story,
  double width,
  double threadHeight,
  TextScaler scaler,
  _Measure measure,
) {
  final single = _single(width);
  final pad = single ? threadExpandedPadSingle : threadExpandedPad;
  final contentW = _expandedWidth(width) - pad * 2;
  final natural = _photoHeight(story, contentW, threadHeight);
  return _capExpanded(
    story,
    contentW,
    natural,
    _photoFloor(story, natural),
    pad,
    single ? threadExpandedTitleSingle : threadExpandedTitle,
    threadHeight,
    scaler,
    measure,
  );
}

double _capExpanded(
  Story story,
  double contentW,
  double natural,
  double floor,
  double pad,
  double titleSize,
  double threadHeight,
  TextScaler scaler,
  _Measure measure,
) {
  final cap = threadHeight - threadAreaCap;
  var photo = natural;
  var card = _expandedBody(
    story,
    contentW,
    photo,
    threadExcerptLines,
    pad,
    titleSize,
    scaler,
    measure,
  );
  if (threadHeight <= 0 || card <= cap) return card;
  final shrunk = photo - (card - cap);
  photo = shrunk > floor ? shrunk : floor;
  card = _expandedBody(
    story,
    contentW,
    photo,
    threadExcerptLines,
    pad,
    titleSize,
    scaler,
    measure,
  );
  if (card <= cap) return card;
  return _expandedBody(
    story,
    contentW,
    photo,
    threadExcerptLinesShrunk,
    pad,
    titleSize,
    scaler,
    measure,
  );
}

double _expandedBody(
  Story story,
  double contentW,
  double photo,
  int excerptLines,
  double pad,
  double titleSize,
  TextScaler scaler,
  _Measure measure,
) {
  return pad +
      photo +
      threadAfterPhoto +
      _date(story, contentW, scaler, measure, FontWeight.w600) +
      threadDateGap +
      measure.height(
        _title(story),
        _news(titleSize, weight: FontWeight.w600),
        contentW,
        threadExpandedTitleLines,
        scaler,
      ) +
      measure.height(
        story.body?.trim() ?? '',
        _literata(threadExcerpt, height: threadExcerptHeight),
        contentW,
        excerptLines,
        scaler,
      ) +
      _chips(story, contentW, scaler, 2) +
      threadBeforeDivider +
      threadDivider +
      _target(scaler) +
      pad;
}

double _quote(Story story, double textW, TextScaler scaler, _Measure measure) {
  final text = measure.height(
    QuoteCard.firstLine(story.body),
    _literata(threadCompactQuote),
    textW - threadBodyPad * 2,
    2,
    scaler,
  );
  final mark = scaler.scale(threadQuoteMark);
  return threadBodyPad + (mark > text ? mark : text) + threadBodyPad;
}

double _photoHeight(Story story, double contentW, double threadHeight) {
  final limit = threadHeight * threadPhotoCapFraction;
  if (story.photoPaths.length >= 2)
    return _fanW(contentW, limit) * 0.75 + threadFanBoxExtra;
  final natural = contentW * 0.75;
  return natural < limit ? natural : limit;
}

double _fanW(double contentW, double limit) {
  var width = contentW - threadFanBoxExtra;
  if (width > threadFanMax) width = threadFanMax;
  final byHeight = limit * 4 / 3;
  if (width > byHeight) width = byHeight;
  if (width < threadFanMin) width = threadFanMin;
  return width;
}

double _photoFloor(Story story, double natural) {
  final floor = story.photoPaths.length >= 2
      ? threadPhotoMin + threadFanBoxExtra
      : threadPhotoMin;
  return natural < floor ? natural : floor;
}

double _chips(Story story, double width, TextScaler scaler, int maxRows) {
  final rows = CardChipLayout(
    people: [for (final person in story.people) person.name],
    place: story.placeLabel,
    maxWidth: width,
    textScaler: scaler,
    maxRows: maxRows,
  ).rows;
  if (rows == 0) return 0;
  final gap = scaler.scale(cardChipSpacing);
  return threadMedallionGap + rows * _chipRow(scaler) + (rows - 1) * gap;
}

double _chipRow(TextScaler scaler) {
  final content = _max(
    scaler.scale(threadChipLabel),
    scaler.scale(cardChipIcon),
  );
  return _max(cardChipHeight, content + cardChipSpacing);
}

double _date(
  Story story,
  double width,
  TextScaler scaler,
  _Measure measure,
  FontWeight weight,
) {
  return measure.height(
    storyDateLabelFor(story),
    _sans(threadDateSize, weight: weight),
    width,
    1,
    scaler,
  );
}

double _cardWidth(double width, double min, double max) {
  final column = threadContentColumn(width);
  if (_single(width)) return column;
  return _clamp(column, min, max);
}

double _expandedWidth(double width) {
  if (_single(width)) return threadContentColumn(width);
  return _clamp(
    width - threadExpandedWidthInset,
    threadExpandedCardMin,
    threadExpandedCardMax,
  );
}

double _target(TextScaler scaler) =>
    _max(threadFooter, scaler.scale(threadFooter));

bool _single(double width) =>
    threadLayoutMode(width) == ThreadLayoutMode.singleSide;

double _clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double _max(double a, double b) => a > b ? a : b;

String _title(Story story) => story.title?.trim() ?? '';

Story? _first(ThreadBeat beat) => switch (beat) {
  StoryBeat(:final story) => story,
  YearBeat(:final stories) => stories.isEmpty ? null : stories.first,
  DecadeBeat(:final stories) => stories.isEmpty ? null : stories.first,
};

YearBeat _year(ThreadBeat beat) => switch (beat) {
  YearBeat() => beat,
  StoryBeat(:final story) => YearBeat(
    year: story.publishedStart.year,
    stories: [story],
  ),
  DecadeBeat(:final decadeStart, :final stories) => YearBeat(
    year: decadeStart,
    stories: stories,
  ),
};

ThreadBeat _sameBeat(ThreadBeat beat) => beat;

String _beatKey(ThreadBeat beat) => switch (beat) {
  StoryBeat(:final story) => 's:${story.id}',
  YearBeat(:final year, :final stories) =>
    'y:$year:${stories.isEmpty ? '' : stories.first.id}',
  DecadeBeat(:final decadeStart) => 'd:$decadeStart',
};

TextStyle _sans(double size, {FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.sourceSans3(fontSize: size, fontWeight: weight);

TextStyle _news(
  double size, {
  FontWeight weight = FontWeight.w400,
  double? height,
  FontStyle? fontStyle,
}) => GoogleFonts.newsreader(
  fontSize: size,
  fontWeight: weight,
  height: height,
  fontStyle: fontStyle,
);

TextStyle _literata(double size, {double? height}) => GoogleFonts.literata(
  fontSize: size,
  fontStyle: FontStyle.italic,
  height: height,
);

final class _Measure {
  final _painter = TextPainter(textDirection: TextDirection.ltr, ellipsis: '…');

  double height(
    String text,
    TextStyle style,
    double width,
    int maxLines,
    TextScaler scaler,
  ) {
    if (text.isEmpty || width <= 0 || maxLines <= 0) return 0;
    _layout(text, style, width, maxLines, scaler);
    return _painter.height;
  }

  int lines(
    String text,
    TextStyle style,
    double width,
    int maxLines,
    TextScaler scaler,
  ) {
    if (text.isEmpty || width <= 0) return 1;
    _layout(text, style, width, maxLines, scaler);
    final count = _painter.computeLineMetrics().length;
    return count == 0 ? 1 : count;
  }

  void _layout(
    String text,
    TextStyle style,
    double width,
    int maxLines,
    TextScaler scaler,
  ) {
    _painter
      ..text = TextSpan(text: text, style: style)
      ..textScaler = scaler
      ..maxLines = maxLines
      ..layout(maxWidth: width < 1 ? 1 : width);
  }
}

final class _ExtentKey {
  const _ExtentKey({
    required this.beat,
    required this.density,
    required this.focused,
    required this.matches,
    required this.width,
    required this.threadHeight,
    required this.scale,
  });

  final String beat;
  final int density;
  final bool focused;
  final bool matches;
  final double width;
  final double threadHeight;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is _ExtentKey &&
      beat == other.beat &&
      density == other.density &&
      focused == other.focused &&
      matches == other.matches &&
      width == other.width &&
      threadHeight == other.threadHeight &&
      scale == other.scale;

  @override
  int get hashCode =>
      Object.hash(beat, density, focused, matches, width, threadHeight, scale);
}

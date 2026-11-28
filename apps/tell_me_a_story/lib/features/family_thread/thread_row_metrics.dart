/// UX §2.4 and §2.5 rendered sizes. Not list extents.

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

ThreadLayoutMode threadLayoutMode(double width) {
  return width >= threadAlternatingMin
      ? ThreadLayoutMode.alternating
      : ThreadLayoutMode.singleSide;
}

double threadSideColumn(double width) {
  return (width - threadBandLane) / 2 - threadSideGap - threadOuterMargin;
}

double threadSingleSideColumn(double width) {
  final tail = width >= threadColumnWideMin ? threadWideTail : threadPhoneTail;
  return width - threadContentLead - tail;
}

double threadContentColumn(double width) {
  return threadLayoutMode(width) == ThreadLayoutMode.singleSide
      ? threadSingleSideColumn(width)
      : threadSideColumn(width);
}

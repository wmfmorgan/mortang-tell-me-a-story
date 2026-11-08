import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// iPad window sizes and insets, from the timeline lab
// (labs/timeline_lab/test/support/ipad.dart).

/// Logical iPad window sizes in points. Split View and Slide Over widths are
/// the iPadOS values for 11"–13" models.
const ipadSizes = <String, Size>{
  'mini_portrait': Size(744, 1133),
  'mini_landscape': Size(1133, 744),
  'air_portrait': Size(820, 1180),
  'air_landscape': Size(1180, 820),
  'pro13_portrait': Size(1024, 1366),
  'pro13_landscape': Size(1366, 1024),
  'split_third': Size(320, 1024),
  'split_third_wide': Size(375, 1024),
  'split_half': Size(507, 1024),
  'split_half_wide': Size(678, 820),
  'slide_over': Size(320, 1133),
};

/// Status bar and home indicator on Face ID iPads.
const ipadTopInset = 24.0;
const ipadBottomInset = 20.0;

/// iPad software keyboard heights (portrait, landscape).
const ipadKeyboardPortrait = 313.0;
const ipadKeyboardLandscape = 398.0;

/// iOS density and padded tap targets, like Flutter web on a real iPad.
final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void setIpadView(WidgetTester tester, Size logical, {double dpr = 2}) {
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  final insets = FakeViewPadding(
    top: ipadTopInset * dpr,
    bottom: ipadBottomInset * dpr,
  );
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  addTearDown(tester.view.reset);
}

/// Shows the software keyboard for a window of [logical] size.
void showKeyboard(WidgetTester tester, Size logical) {
  final dpr = tester.view.devicePixelRatio;
  final height = logical.width > logical.height
      ? ipadKeyboardLandscape
      : ipadKeyboardPortrait;
  tester.view.viewInsets = FakeViewPadding(bottom: height * dpr);
}

/// Runs [body] and returns the first line of every FlutterError it reports
/// (RenderFlex overflows included), so one test can list them all.
Future<List<String>> collectFlutterErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) =>
      errors.add(d.exceptionAsString().split('\n').first);
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

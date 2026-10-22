import 'package:flutter_test/flutter_test.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntil(tester, finder, present: true, timeout: timeout);
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return _pumpUntil(tester, finder, present: false, timeout: timeout);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required bool present,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty == present) return;
  }
  throw TestFailure(
    present
        ? '$finder not found within $timeout (url: ${Uri.base})'
        : '$finder still present within $timeout (url: ${Uri.base})',
  );
}

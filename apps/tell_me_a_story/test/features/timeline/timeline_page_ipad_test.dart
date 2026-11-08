import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/rails/far_rail.dart';

import '../../support/ipad.dart';
import '../../support/timeline_fixture.dart';

// 7.4 iPad: every rail fits every iPad window (the lab's 11 sizes) with the
// status bar and home indicator insets, and with the keyboard up.

const _zooms = <String, String?>{
  'decades': null,
  'years': 'timeline-zoom-mid',
  'days': 'timeline-zoom-full',
};

void main() {
  group('no overflow', () {
    for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
      for (final MapEntry(key: zoom, value: zoomKey) in _zooms.entries) {
        testWidgets('$name $zoom', (tester) async {
          final errors = await collectFlutterErrors(() async {
            setIpadView(tester, size);
            await pumpFixtureTimeline(
              tester,
              stories: fixtureStacked,
              zoomKey: zoomKey,
            );
          });
          expect(errors, isEmpty);
        }, variant: ios);
      }

      testWidgets('$name with the keyboard up', (tester) async {
        final errors = await collectFlutterErrors(() async {
          setIpadView(tester, size);
          await pumpFixtureTimeline(tester, stories: fixtureStacked);
          showKeyboard(tester, size);
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty);
      }, variant: ios);
    }
  });

  // 7.5: the same sweep with a filter active and the filters open: the
  // docked sidebar at 900 pt and up, the end drawer below.
  group('no overflow with the filters open', () {
    Future<void> openFilters(WidgetTester tester, Size size) async {
      await tester.tap(find.byKey(const Key('timeline-filters-open')));
      await tester.pumpAndSettle();
      final wide = size.width >= AlbumBreakpoint.sidebar;
      expect(
        find.byKey(const Key('timeline-filter-sidebar')),
        wide ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('timeline-filter-drawer')),
        wide ? findsNothing : findsOneWidget,
      );
      final chip = find.byKey(Key('filter-person-${fixtureTom.id}'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-status')), findsOneWidget);
    }

    for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
      for (final MapEntry(key: zoom, value: zoomKey) in _zooms.entries) {
        testWidgets('$name $zoom', (tester) async {
          final errors = await collectFlutterErrors(() async {
            setIpadView(tester, size);
            await pumpFixtureTimeline(
              tester,
              stories: fixtureVaried,
              zoomKey: zoomKey,
            );
            await openFilters(tester, size);
          });
          expect(errors, isEmpty);
        }, variant: ios);
      }

      testWidgets('$name searching with the keyboard up', (tester) async {
        final errors = await collectFlutterErrors(() async {
          setIpadView(tester, size);
          await pumpFixtureTimeline(tester, stories: fixtureVaried);
          await openFilters(tester, size);
          await tester.tap(find.byKey(const Key('filter-search')));
          showKeyboard(tester, size);
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('filter-search')), 'zz');
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty);
      }, variant: ios);
    }
  });

  testWidgets('the Decades footer clears the home indicator', (tester) async {
    final size = ipadSizes['mini_portrait']!;
    setIpadView(tester, size);
    await pumpFixtureTimeline(tester);
    final footer = tester.getRect(
      find.textContaining('Stories preserved across the decades'),
    );
    expect(footer.bottom, lessThanOrEqualTo(size.height - ipadBottomInset));
  }, variant: ios);

  testWidgets('the keyboard does not squeeze the rail', (tester) async {
    final size = ipadSizes['mini_landscape']!;
    setIpadView(tester, size);
    await pumpFixtureTimeline(tester);
    final before = tester.getSize(find.byType(FarRail));
    showKeyboard(tester, size);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FarRail)), before);
  }, variant: ios);
}

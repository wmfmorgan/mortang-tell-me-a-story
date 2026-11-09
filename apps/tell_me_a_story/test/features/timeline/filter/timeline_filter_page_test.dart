import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/rails/far_rail.dart';
import 'package:tell_me_a_story/features/timeline/rails/full_card_rail.dart';
import 'package:tell_me_a_story/features/timeline/rails/mid_rail.dart';
import 'package:tell_me_a_story/ui/controls/album_chip.dart';
import 'package:tell_me_a_story/ui/timeline/story_marker.dart';

import '../../../support/timeline_fixture.dart';

// 7.5: dim-only filters on the timeline (Q4). Tom Jenkins is in s1961 and
// s1978; the other four stories dim.

const _desktop = Size(1280, 800);
const _ids = ['s1952', 's1961', 's1975', 's1978', 's1984', 's1999'];
const _titles = {
  's1952': 'The flood year',
  's1961': 'First car',
  's1975': 'Bea moves north',
  's1978': 'Summer at the lake',
  's1984': 'The new kitchen',
  's1999': 'Millennium eve',
};
const _tomStories = {'s1961', 's1978'};

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Dot key prefix per zoom.
const _dotKeys = {
  null: 'timeline-dot-',
  'timeline-zoom-mid': 'timeline-mid-node-',
  'timeline-zoom-full': 'timeline-full-dot-',
};

/// Matched state of every built story dot on the current zoom.
Map<String, bool> _dots(WidgetTester tester, String prefix) {
  final out = <String, bool>{};
  for (final id in _ids) {
    final dots = find.descendant(
      of: find.byKey(Key('$prefix$id')),
      matching: find.byType(StoryDot),
    );
    if (dots.evaluate().isEmpty) continue;
    out[id] = tester.widget<StoryDot>(dots.first).spec.matched;
  }
  return out;
}

Future<void> _tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(Key(key));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _zoom(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

final _open = find.byKey(const Key('timeline-filters-open'));
final _sidebar = find.byKey(const Key('timeline-filter-sidebar'));

/// The varied fixture with the filters open: the sidebar on desktop.
Future<void> _pumpWithFilters(WidgetTester tester, {String? zoomKey}) async {
  await pumpFixtureTimeline(tester, stories: fixtureVaried, zoomKey: zoomKey);
  await tester.tap(_open);
  await tester.pumpAndSettle();
  expect(_sidebar, findsOneWidget);
}

/// A story title, built on or off screen (Days builds every card).
Finder _title(String title) => find.text(title, skipOffstage: false);

Color? _titleColor(WidgetTester tester, String title) =>
    tester.widget<Text>(_title(title)).style?.color;

void main() {
  group('placement', () {
    testWidgets('at 900 pt the sidebar starts closed; the Filters button '
        'beside the zoom switch docks it and closes it', (tester) async {
      _setView(tester, const Size(900, 800));
      await pumpFixtureTimeline(tester, stories: fixtureVaried);
      expect(_sidebar, findsNothing);
      // Closed, the rail has the full width.
      expect(tester.getRect(find.byType(FarRail)).left, 0);
      expect(tester.getRect(find.byType(FarRail)).right, 900);
      expect(_open, findsOneWidget);
      expect(
        find.descendant(of: _open, matching: find.text('Filters')),
        findsOneWidget,
      );
      final zoom = tester.getRect(find.byKey(const Key('timeline-zoom-mid')));
      expect((tester.getCenter(_open).dy - zoom.center.dy).abs(), lessThan(8));
      expect(tester.getRect(_open).right, lessThan(zoom.left));

      await tester.tap(_open);
      await tester.pumpAndSettle();
      expect(_sidebar, findsOneWidget);
      expect(find.byKey(const Key('timeline-filter-drawer')), findsNothing);
      expect(tester.getSize(_sidebar).width, 360);
      // Docked and non-modal: it sits left of the rail, and the rail still
      // answers taps.
      expect(
        tester.getRect(_sidebar).right,
        lessThanOrEqualTo(tester.getRect(find.byType(FarRail)).left),
      );
      await _zoom(tester, 'timeline-zoom-mid');
      expect(find.byType(MidRail), findsOneWidget);
      expect(_sidebar, findsOneWidget);
      await _zoom(tester, 'timeline-zoom-full');
      expect(_sidebar, findsOneWidget);

      await tester.tap(_open);
      await tester.pumpAndSettle();
      expect(_sidebar, findsNothing);
      expect(tester.getRect(find.byType(FullCardRail)).left, 0);
    });

    testWidgets('at 899 pt the Filters button opens the end drawer', (
      tester,
    ) async {
      _setView(tester, const Size(899, 800));
      await pumpFixtureTimeline(tester, stories: fixtureVaried);
      expect(_sidebar, findsNothing);
      expect(_open, findsOneWidget);
      final zoom = tester.getRect(find.byKey(const Key('timeline-zoom-mid')));
      expect((tester.getCenter(_open).dy - zoom.center.dy).abs(), lessThan(8));
      expect(tester.getRect(_open).right, lessThan(zoom.left));

      await tester.tap(_open);
      await tester.pumpAndSettle();
      expect(_sidebar, findsNothing);
      final drawer = find.byKey(const Key('timeline-filter-drawer'));
      expect(drawer, findsOneWidget);
      expect(
        find.descendant(of: drawer, matching: find.text('Filters')),
        findsOneWidget,
      );
      await _tapChip(tester, 'filter-person-${fixtureTom.id}');
      expect(_dots(tester, 'timeline-dot-')['s1952'], isFalse);
    });

    testWidgets('the panel shows the approved sections and hint', (
      tester,
    ) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      final panel = _sidebar;
      for (final label in ['Filters', 'People', 'Places', 'Years']) {
        expect(
          find.descendant(of: panel, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.text('Search titles, stories and people'), findsOneWidget);
      for (final key in [
        'filter-person-${fixtureAda.id}',
        'filter-person-${fixtureTom.id}',
        'filter-person-${fixtureBea.id}',
        'filter-place-${fixtureHarbour.id}',
        'filter-place-${fixtureMill.id}',
        'filter-place-${fixtureNorthgate.id}',
        'filter-decades',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      // No status and no clear action until a filter is active.
      expect(find.byKey(const Key('filter-status')), findsNothing);
      expect(find.byKey(const Key('filter-clear')), findsNothing);
    });
  });

  group('dim, never hide', () {
    for (final MapEntry(key: zoomKey, value: prefix) in _dotKeys.entries) {
      testWidgets('a person filter keeps every dot and hollows the '
          'unmatched (${zoomKey ?? 'Decades'})', (tester) async {
        _setView(tester, _desktop);
        await _pumpWithFilters(tester, zoomKey: zoomKey);
        final before = _dots(tester, prefix);
        expect(before, isNotEmpty);
        expect(before.values, everyElement(isTrue));

        await _tapChip(tester, 'filter-person-${fixtureTom.id}');
        final after = _dots(tester, prefix);
        expect(after.keys, before.keys);
        for (final MapEntry(key: id, value: matched) in after.entries) {
          expect(matched, _tomStories.contains(id), reason: id);
        }
        expect(after.values, contains(false));
        expect(find.byKey(const Key('filter-status')), findsOneWidget);
        expect(find.text('2 of 6 stories match'), findsOneWidget);
      });
    }

    for (final zoomKey in ['timeline-zoom-mid', 'timeline-zoom-full']) {
      testWidgets('unmatched titles use the dim ink ($zoomKey)', (
        tester,
      ) async {
        _setView(tester, _desktop);
        await _pumpWithFilters(tester, zoomKey: zoomKey);
        for (final title in _titles.values) {
          if (_title(title).evaluate().isEmpty) continue;
          expect(_titleColor(tester, title), isNot(albumDimInk));
        }
        await _tapChip(tester, 'filter-person-${fixtureTom.id}');
        var dim = 0;
        var lit = 0;
        for (final MapEntry(key: id, value: title) in _titles.entries) {
          if (_title(title).evaluate().isEmpty) continue;
          final color = _titleColor(tester, title);
          if (_tomStories.contains(id)) {
            expect(color, isNot(albumDimInk), reason: id);
            lit++;
          } else {
            expect(color?.toARGB32(), 0xFF6A6358, reason: id);
            dim++;
          }
        }
        expect(dim, greaterThan(0));
        expect(lit, greaterThan(0));
      });
    }

    testWidgets('Decades counts read "matched of total" while filtering', (
      tester,
    ) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      Finder inRow(int decade, String text) => find.descendant(
        of: find.byKey(Key('timeline-decade-row-$decade')),
        matching: find.textContaining(text),
      );
      expect(inRow(1970, '2 stories'), findsOneWidget);
      await _tapChip(tester, 'filter-person-${fixtureTom.id}');
      expect(inRow(1970, '1 of 2'), findsOneWidget);
      expect(inRow(1950, '0 of 1'), findsOneWidget);
      expect(inRow(1960, '1 of 1'), findsOneWidget);
      // A decade with no match dims its label.
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('timeline-decade-1950')),
          matching: find.text('1950s'),
        ),
      );
      expect(label.style?.color, albumDimInk);
    });

    testWidgets('a query dims by title, body and people', (tester) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      await tester.enterText(find.byKey(const Key('filter-search')), 'bea');
      await tester.pumpAndSettle();
      final dots = _dots(tester, 'timeline-dot-');
      expect(dots.length, 6);
      expect(
        {
          for (final e in dots.entries)
            if (e.value) e.key,
        },
        {'s1975', 's1999'},
      );
    });
  });

  group('no match', () {
    testWidgets('the rails stay mounted under C17, and Clear filters clears', (
      tester,
    ) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      await tester.enterText(find.byKey(const Key('filter-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byType(FarRail), findsOneWidget);
      expect(_dots(tester, 'timeline-dot-').length, 6);
      expect(find.text('No stories match these filters.'), findsOneWidget);
      expect(find.text('0 of 6 stories match'), findsOneWidget);

      await tester.tap(find.byKey(const Key('empty-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('empty-timeline')), findsNothing);
      expect(find.byKey(const Key('filter-status')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('filter-search')))
            .controller
            ?.text,
        '',
      );
      expect(_dots(tester, 'timeline-dot-').values, everyElement(isTrue));
    });

    for (final zoomKey in [null, 'timeline-zoom-mid', 'timeline-zoom-full']) {
      testWidgets('the C17 card is pinned above the rows, covering none '
          '(${zoomKey ?? 'Decades'})', (tester) async {
        _setView(tester, _desktop);
        await _pumpWithFilters(tester, zoomKey: zoomKey);
        await tester.enterText(find.byKey(const Key('filter-search')), 'zzz');
        await tester.pumpAndSettle();
        final card = tester.getRect(find.byKey(const Key('timeline-no-match')));
        final zoom = tester.getRect(find.byKey(const Key('timeline-zoom-mid')));
        final rows = tester.getRect(find.byType(ListView).first);
        // Under the zoom switch, above the scrolling rows.
        expect(card.top, greaterThanOrEqualTo(zoom.bottom));
        expect(card.bottom, lessThanOrEqualTo(rows.top));
        for (final id in _ids) {
          for (final prefix in _dotKeys.values) {
            final dot = find.byKey(Key('$prefix$id'));
            if (dot.evaluate().isEmpty) continue;
            expect(card.overlaps(tester.getRect(dot)), isFalse, reason: id);
          }
        }
      });
    }

    testWidgets('the panel clears with Clear filters too', (tester) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      await _tapChip(tester, 'filter-place-${fixtureMill.id}');
      expect(find.text('2 of 6 stories match'), findsOneWidget);
      await _tapChip(tester, 'filter-clear');
      expect(find.byKey(const Key('filter-status')), findsNothing);
      expect(_dots(tester, 'timeline-dot-').values, everyElement(isTrue));
    });
  });

  group('scope', () {
    testWidgets('the filter survives zoom changes', (tester) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      await _tapChip(tester, 'filter-person-${fixtureTom.id}');
      await _zoom(tester, 'timeline-zoom-mid');
      expect(find.byType(MidRail), findsOneWidget);
      expect(_dots(tester, 'timeline-mid-node-').values, contains(false));
      await _zoom(tester, 'timeline-zoom-full');
      expect(find.byType(FullCardRail), findsOneWidget);
      expect(_dots(tester, 'timeline-full-dot-').values, contains(false));
      await _zoom(tester, 'timeline-zoom-macro');
      expect(_dots(tester, 'timeline-dot-')['s1952'], isFalse);
      expect(find.text('2 of 6 stories match'), findsOneWidget);
      expect(
        tester
            .widget<AlbumChip>(
              find.byKey(Key('filter-person-${fixtureTom.id}')),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('the filter resets on a family switch', (tester) async {
      _setView(tester, _desktop);
      await _pumpWithFilters(tester);
      await _tapChip(tester, 'filter-person-${fixtureTom.id}');
      expect(find.byKey(const Key('filter-status')), findsOneWidget);
      final callout = find.byKey(const Key('timeline-branch-callout-$beaId'));
      await tester.ensureVisible(callout);
      await tester.pumpAndSettle();
      await tester.tap(callout);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-status')), findsNothing);
      expect(_dots(tester, 'timeline-dot-').values, everyElement(isTrue));
    });
  });

  testWidgets('with the filter empty no text uses the dim ink', (tester) async {
    _setView(tester, _desktop);
    await pumpFixtureTimeline(tester, stories: fixtureVaried);
    for (final zoomKey in [null, 'timeline-zoom-mid', 'timeline-zoom-full']) {
      if (zoomKey != null) await _zoom(tester, zoomKey);
      final rail = find.byType(
        zoomKey == null
            ? FarRail
            : zoomKey == 'timeline-zoom-mid'
            ? MidRail
            : FullCardRail,
      );
      final dimTexts = find.descendant(
        of: rail,
        matching: find.byWidgetPredicate(
          (w) => w is Text && w.style?.color == albumDimInk,
        ),
      );
      expect(dimTexts, findsNothing, reason: zoomKey ?? 'Decades');
    }
  });
}

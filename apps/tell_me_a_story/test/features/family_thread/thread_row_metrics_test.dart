import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/card_chip_layout.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_model.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';
import 'package:tell_me_a_story/features/family_thread/thread_row_metrics.dart';
import 'package:tell_me_a_story/features/family_thread/thread_rows.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('overview rows are 104 and the focused decade 148', () {
    final beat = _decade(1990, 'One');
    expect(_extent(beat, FamilyThreadDensity.overview, focused: false), 104);
    expect(_extent(beat, FamilyThreadDensity.overview, focused: true), 148);
  });

  test('browse rows are 88 for a one-line title and 96 for two lines', () {
    expect(
      _extent(_year(1990, 'Hi'), FamilyThreadDensity.browse, focused: false),
      88,
    );
    expect(
      _extent(
        _year(1996, _longTitle),
        FamilyThreadDensity.browse,
        focused: false,
      ),
      96,
    );
  });

  test('non-matching rows are 44', () {
    expect(
      _extent(
        _year(1990, 'Hi'),
        FamilyThreadDensity.browse,
        focused: false,
        matches: false,
      ),
      44,
    );
    expect(
      _extent(
        _storyBeat(2004, 'Newest'),
        FamilyThreadDensity.read,
        focused: false,
        matches: false,
      ),
      44,
    );
  });

  test('landmark row is 56 and never eligible for focus', () {
    final rows = ThreadRows.build(
      [_year(1980, 'Old'), _year(2004, 'Newest')],
      FamilyThreadDensity.browse,
      ThreadFilter.cleared,
    );
    expect(rows.rows.first, isA<ThreadLandmarkRow>());
    expect((rows.rows.first as ThreadLandmarkRow).decadeStart, 1980);
    expect(rows.rows[2], isA<ThreadLandmarkRow>());
    expect(rows.eligible(0), isFalse);
    expect(rows.eligible(1), isTrue);
    expect(threadLandmarkExtent(TextScaler.noScaling), 56);
    final read = ThreadRows.build(
      [_storyBeat(1980, 'Old'), _storyBeat(2004, 'Newest')],
      FamilyThreadDensity.read,
      ThreadFilter.cleared,
    );
    expect(read.rows.whereType<ThreadLandmarkRow>(), hasLength(2));
    expect(read.eligible(0), isFalse);
  });

  test('focused browse row is card height plus 32', () {
    final beat = _year(2004, 'Newest');
    expect(
      _extent(beat, FamilyThreadDensity.browse, focused: true),
      closeTo(_card(beat, FamilyThreadDensity.browse, focused: true) + 32, 0.5),
    );
  });

  test(
    'compact row is card height plus 24 and expanded row card height plus 64',
    () {
      final beat = _storyBeat(2004, 'Newest');
      expect(
        _extent(beat, FamilyThreadDensity.read, focused: false),
        closeTo(
          _card(beat, FamilyThreadDensity.read, focused: false) + 24,
          0.5,
        ),
      );
      expect(
        _extent(beat, FamilyThreadDensity.read, focused: true),
        closeTo(_card(beat, FamilyThreadDensity.read, focused: true) + 64, 0.5),
      );
    },
  );

  test(
    'expanded card never exceeds thread area minus 48 until top-aligned',
    () {
      final beat = _storyBeat(2004, _longTitle, body: _longTitle);
      final roomy = _card(
        beat,
        FamilyThreadDensity.read,
        focused: true,
        threadHeight: 2000,
      );
      expect(roomy, lessThanOrEqualTo(2000 - 48));
      const threadHeight = 220.0;
      final card = _card(
        beat,
        FamilyThreadDensity.read,
        focused: true,
        threadHeight: threadHeight,
      );
      final row = _extent(
        beat,
        FamilyThreadDensity.read,
        focused: true,
        threadHeight: threadHeight,
      );
      expect(row, closeTo(card + 64, 0.5));
      expect(
        card <= threadHeight - 48 ||
            threadRowTopAligns(
              density: FamilyThreadDensity.read,
              focused: true,
              matches: true,
              rowExtent: row,
              threadHeight: threadHeight,
            ),
        isTrue,
      );
      expect(card, greaterThan(threadHeight - 48));
    },
  );

  test('rows grow at 200% text and keep line limits', () {
    final card = _storyBeat(2004, _longTitle, body: _longTitle);
    final scale1 = _extent(card, FamilyThreadDensity.read, focused: true);
    final scale2 = _extent(
      card,
      FamilyThreadDensity.read,
      focused: true,
      scaler: TextScaler.linear(2),
    );
    expect(scale2, greaterThan(scale1));
    final twoLines = _extent(
      _year(1996, _longTitle),
      FamilyThreadDensity.browse,
      focused: false,
      scaler: TextScaler.linear(2),
    );
    final longer = _extent(
      _year(1996, '$_longTitle $_longTitle $_longTitle'),
      FamilyThreadDensity.browse,
      focused: false,
      scaler: TextScaler.linear(2),
    );
    expect(longer, closeTo(twoLines, 0.5));
  });

  test('alternating at a 720 thread area and single-side at 719', () {
    expect(threadLayoutMode(720), ThreadLayoutMode.alternating);
    expect(threadLayoutMode(719), ThreadLayoutMode.singleSide);
  });

  test('side column is 394 at 944 and 282 at 720; single-side column is 302 at 390', () {
    expect(threadSideColumn(944), closeTo(394, 0.001));
    expect(threadSideColumn(720), closeTo(282, 0.001));
    expect(threadSingleSideColumn(390), closeTo(302, 0.001));
  });

  test(
    'cache returns the same value and misses on density, focus, width, scale',
    () {
      final cache = ThreadRowExtentCache();
      final beat = _year(1996, 'Hi');
      final first = _cached(
        cache,
        beat,
        FamilyThreadDensity.browse,
        focused: false,
      );
      expect(cache.misses, 1);
      expect(
        _cached(cache, beat, FamilyThreadDensity.browse, focused: false),
        first,
      );
      expect(cache.misses, 1);
      _cached(cache, beat, FamilyThreadDensity.read, focused: false);
      _cached(cache, beat, FamilyThreadDensity.browse, focused: true);
      _cached(
        cache,
        beat,
        FamilyThreadDensity.browse,
        focused: false,
        width: 800,
      );
      _cached(
        cache,
        beat,
        FamilyThreadDensity.browse,
        focused: false,
        scaler: TextScaler.linear(2),
      );
      expect(cache.misses, 5);
    },
  );

  test('prefix sums rebuild when the filter or thread height changes', () {
    final stories = [
      _story('a', 1980, 'Old', personId: 'ada'),
      _story('b', 2004, 'Newest'),
    ];
    final model = ThreadBeatModel.build(stories);
    final browse = model.beatsFor(FamilyThreadDensity.browse);
    final open = _table(
      browse,
      FamilyThreadDensity.browse,
      ThreadFilter.cleared,
    );
    final filtered = _table(
      browse,
      FamilyThreadDensity.browse,
      const ThreadFilter(personIds: {'ada'}),
    );
    expect(filtered.extents, isNot(open.extents));
    _expectTable(
      filtered,
      browse,
      FamilyThreadDensity.browse,
      const ThreadFilter(personIds: {'ada'}),
    );
    final read = model.beatsFor(FamilyThreadDensity.read);
    final tall = _table(read, FamilyThreadDensity.read, ThreadFilter.cleared);
    final short = _table(
      read,
      FamilyThreadDensity.read,
      ThreadFilter.cleared,
      threadHeight: 220,
    );
    expect(short.extents.last, isNot(closeTo(tall.extents.last, 0.5)));
    _expectTable(
      short,
      read,
      FamilyThreadDensity.read,
      ThreadFilter.cleared,
      220,
    );
  });

  test('chips wrap to at most two rows', () {
    final narrow = CardChipLayout(
      people: [for (var i = 0; i < 8; i++) 'Person number $i'],
      place: 'A very long place name',
      maxWidth: 160,
      textScaler: TextScaler.noScaling,
    );
    expect(narrow.rows, 2);
    expect(
      CardChipLayout(
        people: const [],
        place: null,
        maxWidth: 200,
        textScaler: TextScaler.noScaling,
      ).rows,
      0,
    );
  });

  testWidgets(
    'rendered row heights match threadRowExtent at text scale 1 and 2',
    (tester) async {
      final stories = [
        _story('old', 1980, 'Hi'),
        _story('mid', 1996, _longTitle),
        _story('new', 2004, 'Newest'),
      ];
      await _pump(tester, stories, FamilyThreadDensity.overview, 1);
      _expectRendered(tester, stories, FamilyThreadDensity.overview, 1);
      await _pump(tester, stories, FamilyThreadDensity.browse, 1);
      _expectRendered(tester, stories, FamilyThreadDensity.browse, 1);
      expect(tester.takeException(), isNull);
      await _pump(tester, stories, FamilyThreadDensity.read, 2);
      _expectRendered(tester, stories, FamilyThreadDensity.read, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('extents are not recomputed during a scroll', (tester) async {
    await _pump(
      tester,
      [_story('old', 1980, 'Old'), _story('new', 2004, 'Newest')],
      FamilyThreadDensity.browse,
      1,
    );
    final row = find.byKey(const ValueKey<String>('thread-row-1'));
    final before = tester.getSize(row).height;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ThreadView)),
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(tester.getSize(row).height, before);
    await gesture.up();
  });

  testWidgets('landmark row is 56 and the focus line stays on a beat', (
    tester,
  ) async {
    await _pump(
      tester,
      [_story('old', 1980, 'Old'), _story('new', 2004, 'Newest')],
      FamilyThreadDensity.browse,
      1,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('thread-row-0'))).height,
      closeTo(56, 0.5),
    );
    final mark = tester.getCenter(find.text('1980s'));
    final view = tester.getCenter(find.byType(ThreadView));
    expect((mark.dy - view.dy).abs(), greaterThan(1));
    final tile = tester.getCenter(
      find.byKey(const ValueKey<String>('thread-row-3')),
    );
    expect(tile.dy, closeTo(view.dy, 1));
  });
}

const _width = 944.0;
const _height = 2400.0;
const _longTitle = 'The family walked down to the river and stayed all summer';

double _extent(
  ThreadBeat beat,
  FamilyThreadDensity density, {
  required bool focused,
  bool matches = true,
  double threadHeight = _height,
  double width = _width,
  TextScaler scaler = TextScaler.noScaling,
}) {
  return threadRowExtent(
    beat: beat,
    density: density,
    focused: focused,
    width: width,
    textScaler: scaler,
    matches: matches,
    threadHeight: threadHeight,
  );
}

double _card(
  ThreadBeat beat,
  FamilyThreadDensity density, {
  required bool focused,
  double threadHeight = _height,
}) {
  return threadCardHeight(
    beat: beat,
    density: density,
    focused: focused,
    width: _width,
    textScaler: TextScaler.noScaling,
    threadHeight: threadHeight,
  );
}

double _cached(
  ThreadRowExtentCache cache,
  ThreadBeat beat,
  FamilyThreadDensity density, {
  required bool focused,
  double width = _width,
  TextScaler scaler = TextScaler.noScaling,
}) {
  return cache.extent(
    beat: beat,
    density: density,
    focused: focused,
    width: width,
    textScaler: scaler,
    matches: true,
    threadHeight: _height,
  );
}

({List<double> extents, List<double> offsets}) _table(
  List<ThreadBeat> beats,
  FamilyThreadDensity density,
  ThreadFilter filter, {
  double threadHeight = _height,
}) {
  final rows = ThreadRows.build(beats, density, filter);
  return threadExtentTable(
    rows: rows.rows,
    density: density,
    focusIndex: rows.rowOfBeat(beats.length - 1),
    width: _width,
    threadHeight: threadHeight,
    textScaler: TextScaler.noScaling,
    cache: ThreadRowExtentCache(),
  );
}

void _expectTable(
  ({List<double> extents, List<double> offsets}) table,
  List<ThreadBeat> beats,
  FamilyThreadDensity density,
  ThreadFilter filter, [
  double threadHeight = _height,
]) {
  final rows = ThreadRows.build(beats, density, filter);
  var sum = 0.0;
  for (var i = 0; i < rows.rows.length; i++) {
    final row = rows.rows[i];
    final expected = switch (row) {
      ThreadLandmarkRow() => threadLandmarkExtent(TextScaler.noScaling),
      ThreadBeatRow(:final beat, :final matches) => threadRowExtent(
        beat: beat,
        density: density,
        focused: i == rows.rowOfBeat(beats.length - 1),
        width: _width,
        textScaler: TextScaler.noScaling,
        matches: matches,
        threadHeight: threadHeight,
      ),
    };
    expect(table.extents[i], closeTo(expected, 0.5));
    expect(table.offsets[i], closeTo(sum, 0.5));
    sum += table.extents[i];
  }
}

Future<void> _pump(
  WidgetTester tester,
  List<Story> stories,
  FamilyThreadDensity density,
  double scale,
) async {
  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: albumTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ThreadView(stories: stories, density: density),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectRendered(
  WidgetTester tester,
  List<Story> stories,
  FamilyThreadDensity density,
  double scale,
) {
  final beats = ThreadBeatModel.build(stories).beatsFor(density);
  final table = threadExtentTable(
    rows: ThreadRows.build(beats, density, ThreadFilter.cleared).rows,
    density: density,
    focusIndex: ThreadRows.build(
      beats,
      density,
      ThreadFilter.cleared,
    ).rowOfBeat(beats.length - 1),
    width: _width,
    threadHeight: _height,
    textScaler: TextScaler.linear(scale),
    cache: ThreadRowExtentCache(),
  );
  for (var i = 0; i < table.extents.length; i++) {
    final finder = find.byKey(ValueKey<String>('thread-row-$i'));
    if (finder.evaluate().isEmpty) continue;
    expect(tester.getSize(finder).height, closeTo(table.extents[i], 0.5));
  }
  expect(find.byKey(const ValueKey<String>('thread-row-0')), findsOneWidget);
}

DecadeBeat _decade(int year, String title) =>
    DecadeBeat(decadeStart: year, stories: [_story('s$year', year, title)]);

YearBeat _year(int year, String title) =>
    YearBeat(year: year, stories: [_story('s$year', year, title)]);

StoryBeat _storyBeat(int year, String title, {String? body}) =>
    StoryBeat(story: _story('s$year', year, title, body: body));

Story _story(
  String id,
  int year,
  String title, {
  String? body,
  String? personId,
}) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    body: body,
    personIds: [if (personId != null) personId],
  );
}

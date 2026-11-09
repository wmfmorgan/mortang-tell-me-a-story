@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

import '../support/timeline_fixture.dart';

// The three timeline rails as restyled in 7.4 (markers, continuous corners,
// one spine), on the Jenkins fixture with its Bea branch. Regenerate on
// purpose only. macOS only: `just test-goldens`.

const _desktop = Size(1280, 800);
const _ipadMiniPortrait = Size(744, 1133);
const _ipadMiniLandscape = Size(1133, 744);

const _zooms = <String, String?>{
  'decades': null,
  'years': 'timeline-zoom-mid',
  'days': 'timeline-zoom-full',
};

/// Every zoom at desktop and iPad mini portrait; Decades and Days also at
/// iPad mini landscape.
final _cases = <(String, String, Size)>[
  for (final zoom in ['decades', 'years', 'days']) ...[
    (zoom, 'desktop', _desktop),
    (zoom, 'ipad_mini_portrait', _ipadMiniPortrait),
  ],
  ('decades', 'ipad_mini_landscape', _ipadMiniLandscape),
  ('days', 'ipad_mini_landscape', _ipadMiniLandscape),
];

void main() {
  for (final (zoomName, sizeName, size) in _cases) {
    testWidgets('timeline $zoomName $sizeName', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: albumTheme(),
          builder: albumAppBuilder,
          home: fixturePage(fixturePublished),
        ),
      );
      await tester.pumpAndSettle();
      final zoomKey = _zooms[zoomName];
      if (zoomKey != null) {
        await tester.tap(find.byKey(Key(zoomKey)));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(TimelinePage),
        matchesGoldenFile('timeline/${zoomName}_$sizeName.png'),
      );
    });
  }

  // 7.5: Decades with a Tom Jenkins filter on the varied fixture: the
  // sidebar on desktop, the end drawer open on iPad mini portrait.
  for (final (sizeName, size) in [
    ('desktop', _desktop),
    ('ipad_mini_portrait', _ipadMiniPortrait),
  ]) {
    testWidgets('timeline filtered $sizeName', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: albumTheme(),
          builder: albumAppBuilder,
          home: fixturePage(fixtureVaried),
        ),
      );
      await tester.pumpAndSettle();
      final open = find.byKey(const Key('timeline-filters-open'));
      if (open.evaluate().isNotEmpty) {
        await tester.tap(open);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(Key('filter-person-${fixtureTom.id}')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TimelinePage),
        matchesGoldenFile('timeline/timeline_filtered_$sizeName.png'),
      );
    });
  }
}

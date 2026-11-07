import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/model/lab_models.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/renderers/painter_rail_renderer.dart';

LabStory _s(String id, DateTime start, {String family = 'fam-root'}) =>
    LabStory(
      id: id,
      familyId: family,
      title: id,
      body: '',
      start: start,
      precision: DatePrecision.day,
      createdAt: DateTime.utc(2025),
      placeId: null,
      personIds: const [],
      photoCount: 0,
    );

LabDataset _dataset(List<LabStory> stories) => LabDataset(
  stories: stories,
  people: const {},
  places: const {},
  families: const {
    'fam-root': LabFamily(id: 'fam-root', name: 'Morgan'),
    'fam-reyes': LabFamily(
      id: 'fam-reyes',
      name: 'Reyes',
      parentFamilyId: 'fam-root',
      branchYear: 1978,
    ),
  },
);

List<TimelineEntry> _entries(LabDataset d) => [
  for (final s in d.stories) TimelineEntry(story: s, matched: true),
];

String? _pointId(RailHit? hit) => switch (hit) {
  RailPointHit(:final storyId) => storyId,
  _ => null,
};

void main() {
  test('hitTest finds a point at its centre and nothing 20px away', () {
    final d = _dataset([
      _s('a', DateTime.utc(1950, 1, 1)),
      _s('b', DateTime.utc(1960, 1, 1)),
      _s('c', DateTime.utc(1980, 6, 1), family: 'fam-reyes'),
    ]);
    final g = PainterRailGeometry(_entries(d), d);
    for (final p in g.points) {
      expect(_pointId(g.hitTest(p.center)), p.storyId);
      expect(g.hitTest(p.center + const Offset(20, 0)), isNull);
    }
  });

  test('stacked dots 10px apart resolve to the nearest one', () {
    final d = _dataset([
      for (var i = 0; i < 3; i++) _s('s$i', DateTime.utc(1970, 3, 1 + i)),
    ]);
    final g = PainterRailGeometry(_entries(d), d);
    // Each stacked dot is within the 12px radius of its neighbours.
    for (final p in g.points) {
      expect(_pointId(g.hitTest(p.center)), p.storyId);
    }
  });

  test('coincident points stack to four, then a badge holding the rest', () {
    final d = _dataset([
      for (var i = 0; i < 6; i++) _s('s$i', DateTime.utc(1970, 3, 1 + i)),
    ]);
    final g = PainterRailGeometry(_entries(d), d);
    expect(g.points, hasLength(4));
    expect(g.overflowBadges.single.storyIds, ['s4', 's5']);
    final hit = g.hitTest(g.overflowBadges.single.at);
    expect(hit, isA<RailBadgeHit>());
  });

  test('badge taps cycle through every hidden story', () {
    const badge = RailBadge(at: Offset.zero, storyIds: ['x', 'y', 'z']);
    expect(nextInBadge(badge, null), 'x');
    expect(nextInBadge(badge, 'x'), 'y');
    expect(nextInBadge(badge, 'z'), 'x');
    expect(nextInBadge(badge, 'not-in-badge'), 'x');
  });

  test('every story is reachable through a point or a badge at 5k', () {
    final d = generateDataset(storyCount: 5000);
    final g = PainterRailGeometry(_entries(d), d);
    final reachable = {
      for (final p in g.points) p.storyId,
      for (final b in g.overflowBadges) ...b.storyIds,
    };
    expect(reachable, hasLength(d.stories.length));
    // Most stories collapse into badges at this density.
    expect(g.points.length, lessThan(d.stories.length ~/ 2));
  });
}

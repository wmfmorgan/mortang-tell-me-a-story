import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';

/// One family tree for the whole-tree tests and goldens: Jenkins (root) with
/// two branches, Bea (from the 1975 story) and Cal (from 1984), and 13
/// published stories across 1950–1999. One story has no tagged person.
abstract final class TreeFixture {
  static const jenkins = '00000000-0000-0000-0000-000000000001';
  static const bea = '00000000-0000-0000-0000-0000000000be';
  static const cal = '00000000-0000-0000-0000-0000000000ca';

  static const ada = (id: 'p-ada', name: 'Ada Jenkins');
  static const tom = (id: 'p-tom', name: 'Tom Jenkins');
  static const beaP = (id: 'p-bea', name: 'Bea Jenkins');
  static const calP = (id: 'p-cal', name: 'Cal Jenkins');

  static const tree = <TreeFamily>[
    TreeFamily(id: jenkins, name: 'Jenkins'),
    TreeFamily(
      id: bea,
      name: 'Bea',
      parentFamilyId: jenkins,
      originStoryId: 's1975',
      branchYear: 1975,
    ),
    TreeFamily(
      id: cal,
      name: 'Cal',
      parentFamilyId: jenkins,
      originStoryId: 's1984',
      branchYear: 1984,
    ),
  ];

  /// In timeline order.
  static final stories = <Story>[
    story('s1952', jenkins, 'The flood year', DateTime(1952, 3, 14), [ada]),
    story('s1958', jenkins, 'Wedding at St Mary', DateTime(1958, 5, 3), [
      ada,
      tom,
    ]),
    story('s1961', jenkins, 'First car', DateTime(1961, 6, 2), [tom]),
    story('s1966', jenkins, 'The long winter', DateTime(1966, 1, 9), []),
    story('s1975', jenkins, 'Bea moves north', DateTime(1975, 8, 9), [beaP]),
    story('b1977', bea, 'A house by the river', DateTime(1977, 4, 2), [beaP]),
    story('s1978', jenkins, 'Summer at the lake', DateTime(1978, 7, 1), [tom]),
    story('b1982', bea, 'Twins!', DateTime(1982, 10, 30), [beaP]),
    story('s1984', jenkins, 'The new kitchen', DateTime(1984, 1, 20), [calP]),
    story('c1986', cal, 'Cal starts the bakery', DateTime(1986, 3, 1), [calP]),
    story('b1991', bea, 'The river floods again', DateTime(1991, 2, 11), [
      beaP,
    ]),
    story('c1993', cal, 'Second shop', DateTime(1993, 9, 5), [calP]),
    story('s1999', jenkins, 'Millennium eve', DateTime(1999, 12, 31), [
      ada,
      tom,
    ]),
  ];

  /// [stories] plus six more Jenkins stories in the 1960s (eight there in
  /// all), in timeline order, so the tree graph shows five and `+3`.
  static final crowded = <Story>[
    ...stories,
    for (final year in const [1960, 1962, 1963, 1964, 1967, 1969])
      story('x$year', jenkins, 'Sixties $year', DateTime(year, 2, 1), [tom]),
  ]..sort((a, b) => a.publishedStart.compareTo(b.publishedStart));

  /// [count] stories over five families (Jenkins → A, B; A → A1; B → B1),
  /// 1900–2019, in timeline order. Every branch starts at the first story
  /// of its parent.
  static ({List<Story> stories, List<TreeFamily> tree}) synthetic(int count) {
    const fams = ['root', 'a', 'b', 'a1', 'b1'];
    final stories = <Story>[
      for (var i = 0; i < count; i++)
        story(
          'syn$i',
          fams[i % fams.length],
          'Story $i',
          DateTime(1900 + i * 120 ~/ count, 1 + i % 12, 1 + i % 28),
          const [],
        ),
    ];
    String originIn(String family) =>
        stories.firstWhere((s) => s.familyId == family).id;
    final tree = [
      const TreeFamily(id: 'root', name: 'Jenkins'),
      for (final (id, parent) in const [
        ('a', 'root'),
        ('b', 'root'),
        ('a1', 'a'),
        ('b1', 'b'),
      ])
        TreeFamily(
          id: id,
          name: id.toUpperCase(),
          parentFamilyId: parent,
          originStoryId: originIn(parent),
        ),
    ];
    return (stories: stories, tree: tree);
  }

  static Story story(
    String id,
    String familyId,
    String title,
    DateTime start,
    List<({String id, String name})> people,
  ) {
    return Story(
      id: id,
      familyId: familyId,
      authorId: 'u1',
      title: title,
      body: 'Told at the kitchen table.',
      timeframeStart: start,
      timeframeEnd: start,
      status: StoryStatus.published,
      personIds: [for (final p in people) p.id],
      people: people,
      personNames: [for (final p in people) p.name],
      publishedAt: DateTime.utc(2026, 9, 27),
      createdAt: DateTime.utc(2026, 9, 27),
    );
  }
}

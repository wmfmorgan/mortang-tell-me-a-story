import 'dart:math' as math;

import 'lab_models.dart';

/// Dataset sizes offered by the UI and used by tests.
const datasetSizes = [120, 1000, 5000];

const _firstYear = 1925;
const _lastYear = 2024;

const _personNames = [
  'Ada Morgan',
  'Ben Morgan',
  'Clara Reyes',
  'Diego Reyes',
  'Esther Morgan',
  'Felix Okafor',
  'Grace Okafor',
  'Hugo Morgan',
  'Iris Reyes',
  'June Okafor',
];

const _placeLabels = [
  'Lake Tahoe',
  'Brooklyn',
  'Oaxaca',
  'Lagos',
  'Grandma\'s farm',
  'Portland',
  'Seaside',
  'Chicago',
];

const _titleFirst = [
  'Summer',
  'Winter',
  'A wedding',
  'The first car',
  'Sunday dinner',
  'A long drive',
  'Moving day',
  'Graduation',
  'The storm',
  'A birthday',
  'Harvest',
  'The reunion',
];

const _titleSecond = [
  'at the lake',
  'in the city',
  'on the farm',
  'by the sea',
  'at home',
  'with cousins',
  'in the snow',
  'after the war',
  'before school',
  'under the oak',
];

const _bodyVerbs = [
  'remembered',
  'wrote about',
  'laughed about',
  'told us about',
  'never forgot',
  'photographed',
];

const _bodyObjects = [
  'the old radio',
  'a red bicycle',
  'the kitchen table',
  'a borrowed coat',
  'the porch light',
  'a jar of buttons',
  'the train station',
  'a handwritten letter',
];

const _rootId = 'fam-root';
const _reyesId = 'fam-reyes';
const _okaforId = 'fam-okafor';

/// Deterministic synthetic dataset. Same [seed] and [storyCount] → same data.
LabDataset generateDataset({int seed = 42, int storyCount = 120}) {
  final rng = math.Random(seed);

  final people = {
    for (var i = 0; i < _personNames.length; i++)
      'p-$i': LabPerson(id: 'p-$i', name: _personNames[i]),
  };
  final places = {
    for (var i = 0; i < _placeLabels.length; i++)
      'pl-$i': LabPlace(id: 'pl-$i', label: _placeLabels[i]),
  };
  final baseFamilies = const [
    LabFamily(id: _rootId, name: 'Morgan'),
    LabFamily(
      id: _reyesId,
      name: 'Reyes',
      parentFamilyId: _rootId,
      branchYear: 1978,
    ),
    LabFamily(
      id: _okaforId,
      name: 'Okafor',
      parentFamilyId: _rootId,
      branchYear: 1996,
    ),
  ];
  final branchYearOf = {
    for (final f in baseFamilies) f.id: f.branchYear ?? _firstYear,
  };

  final stories = <LabStory>[];
  for (var i = 0; i < storyCount; i++) {
    final familyRoll = rng.nextDouble();
    final familyId = familyRoll < 0.6
        ? _rootId
        : familyRoll < 0.8
        ? _reyesId
        : _okaforId;
    final minYear = branchYearOf[familyId]!;
    final year = minYear + rng.nextInt(_lastYear - minYear + 1);

    final precisionRoll = rng.nextDouble();
    final precision = precisionRoll < 0.5
        ? DatePrecision.year
        : precisionRoll < 0.8
        ? DatePrecision.month
        : DatePrecision.day;
    final month = precision == DatePrecision.year ? 1 : 1 + rng.nextInt(12);
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    final day = precision == DatePrecision.day
        ? 1 + rng.nextInt(daysInMonth)
        : 1;

    final personCount = rng.nextInt(4);
    final personIds = <String>{};
    while (personIds.length < personCount) {
      personIds.add('p-${rng.nextInt(_personNames.length)}');
    }
    final sortedPeople = personIds.toList()..sort();

    final placeId = rng.nextDouble() < 0.15
        ? null
        : 'pl-${rng.nextInt(_placeLabels.length)}';
    final photoCount = rng.nextInt(5);

    final title =
        '${_titleFirst[rng.nextInt(_titleFirst.length)]} '
        '${_titleSecond[rng.nextInt(_titleSecond.length)]}';
    final body =
        'Everyone ${_bodyVerbs[rng.nextInt(_bodyVerbs.length)]} '
        '${_bodyObjects[rng.nextInt(_bodyObjects.length)]}.';

    stories.add(
      LabStory(
        id: 's-${i.toString().padLeft(4, '0')}',
        familyId: familyId,
        title: title,
        body: body,
        start: DateTime.utc(year, month, day),
        precision: precision,
        createdAt: DateTime.utc(2025, 1, 1).add(Duration(minutes: i)),
        placeId: placeId,
        personIds: List.unmodifiable(sortedPeople),
        photoCount: photoCount,
      ),
    );
  }

  // The branch starts at the earliest root-family story in or after its
  // branch year (chronologically, not in generation order).
  final chronological = [...stories]..sort(compareLabStories);
  String? originFor(LabFamily f) {
    if (!f.isBranch) return null;
    for (final s in chronological) {
      if (s.familyId == _rootId && s.start.year >= f.branchYear!) return s.id;
    }
    return null;
  }

  final families = {
    for (final f in baseFamilies) f.id: f.withOrigin(originFor(f)),
  };

  return LabDataset(
    stories: stories,
    people: people,
    places: places,
    families: families,
  );
}

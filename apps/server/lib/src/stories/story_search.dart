import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

const _year = 'extract(year FROM st."dateStart")::int';
const _decade = '(extract(year FROM st."dateStart")::int / 10 * 10)';
const _scope = 'st."familyId" = @familyId::uuid AND st.status = \'published\'';
const _newestFirst =
    '"dateStart" DESC, "datePrecision" DESC, "createdAt" DESC, s.id DESC';

/// Ids of the published stories of `q.familyId` matching [q], in result
/// order (endpoint-contract §2.2, search semantics). Authorization is the
/// caller's job.
///
/// - `personIds`: AND (every person tagged); `placeId`: exact.
/// - `decades` non-empty: `floor(year/10)*10 ∈ decades`; otherwise, when
///   both range bounds are set, overlap with `[rangeStart, rangeEnd]`.
/// - `text` (trimmed): case-insensitive substring (ILIKE, `%`/`_`/`\`
///   escaped) over title (tier 3), person names / place label / address
///   (tier 2), body / start year / `'<decade>s'` (tier 1).
/// - sorts: `relevant` = tier desc, then newest timeline first;
///   `chronological` = newest timeline first; `recentlyAdded` = publishedAt
///   desc nulls last, then newest timeline first.
Future<List<UuidValue>> searchStoryIds(
  Session session,
  StorySearchDto q,
) async {
  final params = <String, Object?>{'familyId': q.familyId.uuid};
  final where = [_scope];

  final personIds = {for (final id in q.personIds) id.uuid}.toList();
  if (personIds.isNotEmpty) {
    params['personIds'] = personIds;
    params['personCount'] = personIds.length;
    where.add(
      '(SELECT count(*) FROM story_people sp WHERE sp."storyId" = st.id '
      'AND sp."personId" = ANY(@personIds::uuid[])) = @personCount',
    );
  }
  final placeId = q.placeId;
  if (placeId != null) {
    params['placeId'] = placeId.uuid;
    where.add('st."placeId" = @placeId::uuid');
  }
  final rangeStart = q.rangeStart;
  final rangeEnd = q.rangeEnd;
  if (q.decades.isNotEmpty) {
    params['decades'] = q.decades.toSet().toList();
    where.add('$_decade = ANY(@decades::int[])');
  } else if (rangeStart != null && rangeEnd != null) {
    params['rangeStart'] = rangeStart;
    params['rangeEnd'] = rangeEnd;
    where.add('st."dateStart" <= @rangeEnd AND @rangeStart <= st."dateEnd"');
  }

  final text = q.text.trim();
  var tier = '0';
  if (text.isNotEmpty) {
    params['pattern'] = '%${_escapeLike(text)}%';
    tier =
        'CASE '
        'WHEN st.title ILIKE @pattern THEN 3 '
        'WHEN pl.label ILIKE @pattern OR pl.address ILIKE @pattern '
        'OR EXISTS (SELECT 1 FROM story_people sp '
        'JOIN people p ON p.id = sp."personId" '
        'WHERE sp."storyId" = st.id AND p.name ILIKE @pattern) THEN 2 '
        'WHEN st.body ILIKE @pattern OR $_year::text ILIKE @pattern '
        "OR ($_decade::text || 's') ILIKE @pattern THEN 1 "
        'ELSE 0 END';
  }
  final order = switch (q.sort) {
    SearchSort.relevant => 'tier DESC, $_newestFirst',
    SearchSort.chronological => _newestFirst,
    SearchSort.recentlyAdded => '"publishedAt" DESC NULLS LAST, $_newestFirst',
  };
  final rows = await session.db.unsafeQuery(
    'SELECT s.id::text FROM ('
    'SELECT st.id, st."dateStart", st."datePrecision", st."createdAt", '
    'st."publishedAt", $tier AS tier '
    'FROM stories st LEFT JOIN places pl ON pl.id = st."placeId" '
    'WHERE ${where.join(' AND ')}'
    ') s ${text.isEmpty ? '' : 'WHERE tier > 0 '}'
    'ORDER BY $order',
    parameters: QueryParameters.named(params),
  );
  return [for (final row in rows) UuidValue.fromString(row[0] as String)];
}

/// Facets over the same scope as [searchStoryIds] without filters: decades
/// ascending, tagged people (any home family) by name, places by label.
Future<StoryFacetsDto> storyFacets(Session session, UuidValue familyId) async {
  final params = QueryParameters.named({'familyId': familyId.uuid});
  final decades = await session.db.unsafeQuery(
    'SELECT $_decade, count(*)::int FROM stories st WHERE $_scope '
    'GROUP BY 1 ORDER BY 1',
    parameters: params,
  );
  final people = await session.db.unsafeQuery(
    'SELECT p.id::text, p.name, count(*)::int FROM stories st '
    'JOIN story_people sp ON sp."storyId" = st.id '
    'JOIN people p ON p.id = sp."personId" '
    'WHERE $_scope GROUP BY p.id, p.name ORDER BY p.name, p.id',
    parameters: params,
  );
  final places = await session.db.unsafeQuery(
    'SELECT pl.id::text, pl.label, count(*)::int FROM stories st '
    'JOIN places pl ON pl.id = st."placeId" '
    'WHERE $_scope GROUP BY pl.id, pl.label ORDER BY pl.label, pl.id',
    parameters: params,
  );
  return StoryFacetsDto(
    decades: [
      for (final row in decades)
        DecadeFacetDto(decade: row[0] as int, storyCount: row[1] as int),
    ],
    people: [
      for (final row in people)
        PersonFacetDto(
          personId: UuidValue.fromString(row[0] as String),
          name: row[1] as String,
          storyCount: row[2] as int,
        ),
    ],
    places: [
      for (final row in places)
        PlaceFacetDto(
          placeId: UuidValue.fromString(row[0] as String),
          label: row[1] as String,
          storyCount: row[2] as int,
        ),
    ],
  );
}

/// [text] with LIKE wildcards and the escape character escaped.
String _escapeLike(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');

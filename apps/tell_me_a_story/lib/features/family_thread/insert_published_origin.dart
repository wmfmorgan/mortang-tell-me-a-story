import '../../data/stories_api.dart';

/// Inserts [origin] where `listPublished` would have placed it.
///
/// Keys, in order: `timeframe_start` ascending with nulls last, then
/// `date_precision` in `story_date_precision` declaration order
/// (decade, year, month, day), then `created_at`, then `id`.
/// Other rows keep their order.
List<Story> insertPublishedOrigin(List<Story> rows, Story origin) {
  for (final story in rows) {
    if (story.id == origin.id) return rows;
  }
  final index = rows.indexWhere((story) => compareStories(origin, story) < 0);
  if (index < 0) return [...rows, origin];
  return [...rows.sublist(0, index), origin, ...rows.sublist(index)];
}

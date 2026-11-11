import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_recents.g.dart';

/// Last three submitted search strings for this app session.
@Riverpod(keepAlive: true)
class SearchRecents extends _$SearchRecents {
  @override
  List<String> build() => const [];

  void remember(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    state = List.unmodifiable(
      [query, ...state.where((q) => q != query)].take(3),
    );
  }
}

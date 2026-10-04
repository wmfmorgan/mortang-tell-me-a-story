import 'package:flutter/foundation.dart';

/// Last three submitted search strings for this app session.
class SearchRecents extends ChangeNotifier {
  final _queries = <String>[];

  List<String> get queries => List.unmodifiable(_queries);

  void remember(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    _queries.remove(query);
    _queries.insert(0, query);
    if (_queries.length > 3) _queries.removeLast();
    notifyListeners();
  }
}

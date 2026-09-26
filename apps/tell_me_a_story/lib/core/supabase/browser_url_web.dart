// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Replace the address bar without a reload (keeps `invite`, drops auth params).
void replaceBrowserUrl(Uri uri) {
  final pathAndQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  final url = pathAndQuery.isEmpty ? '/' : pathAndQuery;
  html.window.history.replaceState(null, '', url);
}

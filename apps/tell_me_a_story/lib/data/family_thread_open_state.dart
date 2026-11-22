import 'dart:convert';

import 'family_thread_density.dart';

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

class FamilyThreadOpenState {
  const FamilyThreadOpenState({required this.density, required this.storyId});

  final FamilyThreadDensity density;
  final String storyId;

  String encode() {
    return jsonEncode({'density': density.name, 'storyId': storyId});
  }

  static FamilyThreadOpenState? tryDecode(String raw) {
    if (utf8.encode(raw).length > 256) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded case {
      'density': final String name,
      'storyId': final String storyId,
    }) {
      if (decoded.length != 2 || !_uuid.hasMatch(storyId)) return null;
      final density = switch (name) {
        'overview' => FamilyThreadDensity.overview,
        'browse' => FamilyThreadDensity.browse,
        'read' => FamilyThreadDensity.read,
        _ => null,
      };
      if (density == null) return null;
      return FamilyThreadOpenState(density: density, storyId: storyId);
    }
    return null;
  }
}

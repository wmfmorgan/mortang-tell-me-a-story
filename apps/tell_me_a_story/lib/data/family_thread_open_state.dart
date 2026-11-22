import 'dart:convert';

import 'family_thread_density.dart';
import 'uuid.dart';

class FamilyThreadOpenState {
  const FamilyThreadOpenState({required this.density, required this.storyId});

  static const maxBytes = 256;

  final FamilyThreadDensity density;
  final String storyId;

  String encode() {
    return jsonEncode({'density': density.name, 'storyId': storyId});
  }

  static FamilyThreadOpenState? tryDecode(String raw) {
    if (utf8.encode(raw).length > maxBytes) return null;
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
      if (decoded.length != 2 || !isUuid(storyId)) return null;
      final density = FamilyThreadDensity.values.asNameMap()[name];
      if (density == null) return null;
      return FamilyThreadOpenState(density: density, storyId: storyId);
    }
    return null;
  }
}

/// Process-memory family choice. Not a table and not kept across a restart.
class FamilySelection {
  static String? _familyId;
  static String? _userId;

  static String? get id => _familyId;

  static void remember(String familyId) {
    _familyId = familyId;
  }

  static void clear() {
    _familyId = null;
    _userId = null;
  }

  /// Drops the remembered id when it is the family that was just soft-deleted.
  static void forget(String familyId) {
    if (_familyId == familyId) _familyId = null;
  }

  /// Binds [userId] as the signed-in user.
  ///
  /// A different user clears the remembered family. The same user keeps it.
  /// Returns the remembered id after that check.
  static String? bindUser(String userId) {
    if (_userId != userId) {
      if (_userId != null) _familyId = null;
      _userId = userId;
    }
    return _familyId;
  }
}

/// Picks the family id without reading the network.
///
/// A signed-out user returns null and does not use [membershipIds] or
/// [fallback]. A remembered id is returned only when [membershipIds] contains
/// it. Otherwise the caller’s unordered `limit(1)` [fallback] is used.
String? resolveCurrentFamilyId({
  required String? userId,
  required String? remembered,
  List<String>? membershipIds,
  String? fallback,
}) {
  if (userId == null) return null;
  if (remembered != null &&
      membershipIds != null &&
      membershipIds.contains(remembered)) {
    return remembered;
  }
  return fallback;
}

/// [name] trimmed, or `Member` when it is missing or blank.
String displayNameOrMember(String? name) {
  final t = name?.trim() ?? '';
  return t.isEmpty ? 'Member' : t;
}

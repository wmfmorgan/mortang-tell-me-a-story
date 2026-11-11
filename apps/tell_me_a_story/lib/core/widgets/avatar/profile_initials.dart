/// First letter of each whitespace-separated word, uppercased.
///
/// Sarah Morgan is SM. A blank name is empty. This is not a column and it
/// does not read an email.
String profileInitials(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return '';
  final buffer = StringBuffer();
  for (final word in name.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    buffer.write(word[0].toUpperCase());
  }
  return buffer.toString();
}

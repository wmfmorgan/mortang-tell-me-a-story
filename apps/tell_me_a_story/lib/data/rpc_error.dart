import 'package:supabase_flutter/supabase_flutter.dart';

/// Detail after one of the four RPC prefixes, or null when none match.
String? mapRpcError(Object error) {
  final raw = error is PostgrestException ? error.message : '';
  final trimmed = raw.trim();
  const prefixes = [
    'NOT_FOUND:',
    'FORBIDDEN:',
    'VALIDATION:',
    'INVITE_INVALID:',
  ];
  for (final prefix in prefixes) {
    if (!trimmed.startsWith(prefix)) continue;
    final detail = trimmed.substring(prefix.length).trim();
    return detail.isEmpty ? trimmed : detail;
  }
  return null;
}

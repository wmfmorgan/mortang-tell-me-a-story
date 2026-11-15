import 'package:supabase_flutter/supabase_flutter.dart';

/// Which failure [mapRpcError] reads. [detail] is the four RPC prefixes.
enum RpcErrorMatch {
  detail,
  notFoundPrefix,
  duplicateStoryKey,
  missingCoverColumn,
  storyPeopleDuplicate,
  originForbidden,
  originNotFound,
  originValidation,
}

/// Detail after one of the four RPC prefixes, or null when none match.
String? mapRpcError(
  Object error, {
  RpcErrorMatch match = RpcErrorMatch.detail,
}) {
  final raw = error is PostgrestException ? error.message : '';
  return switch (match) {
    RpcErrorMatch.detail => _prefixDetail(raw, null),
    RpcErrorMatch.notFoundPrefix => _prefixDetail(raw, 'NOT_FOUND:'),
    RpcErrorMatch.duplicateStoryKey => _duplicateStoryKey(error),
    RpcErrorMatch.missingCoverColumn => _missingCoverColumn(error),
    RpcErrorMatch.storyPeopleDuplicate => _storyPeopleDuplicate(error),
    RpcErrorMatch.originForbidden => _originCatalog(error, 'FORBIDDEN'),
    RpcErrorMatch.originNotFound => _originCatalog(error, 'NOT_FOUND'),
    RpcErrorMatch.originValidation => _originValidation(error),
  };
}

String? _prefixDetail(String raw, String? only) {
  final trimmed = raw.trim();
  const prefixes = <String>[
    'NOT_FOUND:',
    'FORBIDDEN:',
    'VALIDATION:',
    'INVITE_INVALID:',
  ];
  for (final prefix in prefixes) {
    if (only != null && prefix != only) continue;
    if (!trimmed.startsWith(prefix)) continue;
    final detail = trimmed.substring(prefix.length).trim();
    return detail.isEmpty ? trimmed : detail;
  }
  return null;
}

String? _duplicateStoryKey(Object error) {
  if (error is! PostgrestException) return null;
  if (error.code == '23505') return 'duplicate key';
  final text = error.message.toLowerCase();
  if (text.contains('duplicate key')) return 'duplicate key';
  return null;
}

String? _missingCoverColumn(Object error) {
  if (error is! PostgrestException) return null;
  final text = error.message.toLowerCase();
  if (!text.contains('cover_photo_path')) return null;
  final missing =
      error.code == '42703' ||
      error.code == 'PGRST204' ||
      text.contains('does not exist') ||
      text.contains('schema cache');
  return missing ? 'cover_photo_path' : null;
}

String? _storyPeopleDuplicate(Object error) {
  if (error is! PostgrestException) return null;
  if (error.code != '23505') return null;
  final text = error.message;
  if (!text.contains('story_people_pkey')) return null;
  return 'story_people_pkey';
}

String? _originCatalog(Object error, String code) {
  if (error is! PostgrestException) return null;
  final text = error.message;
  if (!text.contains(code)) return null;
  return switch (code) {
    'FORBIDDEN' => 'You do not have permission to do that.',
    'NOT_FOUND' => 'Not found.',
    _ => null,
  };
}

String? _originValidation(Object error) {
  if (error is! PostgrestException) return null;
  final text = error.message;
  if (!text.contains('VALIDATION')) return null;
  const marker = 'VALIDATION: ';
  final index = text.indexOf(marker);
  if (index < 0) return text;
  final detail = text.substring(index + marker.length).trim();
  return detail;
}

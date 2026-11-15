import 'package:supabase_flutter/supabase_flutter.dart';

/// Predicate and origin-catalog matches. Prefix detail stays on [mapRpcError].
enum RpcErrorMatch {
  notFoundPrefix,
  duplicateStoryKey,
  missingCoverColumn,
  storyPeopleDuplicate,
  originForbidden,
  originNotFound,
  originValidation,
}

/// Detail after one of the four RPC prefixes, or null when none match.
String? mapRpcError(Object error) {
  final raw = error is PostgrestException ? error.message : '';
  return _prefixDetail(raw, null);
}

/// True when [error] is the PostgREST case named by [match].
bool rpcErrorIs(Object error, RpcErrorMatch match) {
  return switch (match) {
    RpcErrorMatch.notFoundPrefix => _hasNotFoundPrefix(error),
    RpcErrorMatch.duplicateStoryKey => _duplicateStoryKey(error),
    RpcErrorMatch.missingCoverColumn => _missingCoverColumn(error),
    RpcErrorMatch.storyPeopleDuplicate => _storyPeopleDuplicate(error),
    RpcErrorMatch.originForbidden ||
    RpcErrorMatch.originNotFound ||
    RpcErrorMatch.originValidation => rpcOriginDetail(error, match) != null,
  };
}

/// Catalog text for an origin RPC failure. Null for other matches.
String? rpcOriginDetail(Object error, RpcErrorMatch match) {
  return switch (match) {
    RpcErrorMatch.originForbidden ||
    RpcErrorMatch.originNotFound => _originCatalog(error, match),
    RpcErrorMatch.originValidation => _originValidation(error),
    RpcErrorMatch.notFoundPrefix ||
    RpcErrorMatch.duplicateStoryKey ||
    RpcErrorMatch.missingCoverColumn ||
    RpcErrorMatch.storyPeopleDuplicate => null,
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

bool _hasNotFoundPrefix(Object error) {
  if (error is! PostgrestException) return false;
  return _prefixDetail(error.message, 'NOT_FOUND:') != null;
}

bool _duplicateStoryKey(Object error) {
  if (error is! PostgrestException) return false;
  if (error.code == '23505') return true;
  final text = error.message.toLowerCase();
  return text.contains('duplicate key');
}

bool _missingCoverColumn(Object error) {
  if (error is! PostgrestException) return false;
  final text = error.message.toLowerCase();
  if (!text.contains('cover_photo_path')) return false;
  return error.code == '42703' ||
      error.code == 'PGRST204' ||
      text.contains('does not exist') ||
      text.contains('schema cache');
}

bool _storyPeopleDuplicate(Object error) {
  if (error is! PostgrestException) return false;
  if (error.code != '23505') return false;
  final text = error.message;
  return text.contains('story_people_pkey');
}

String? _originCatalog(Object error, RpcErrorMatch match) {
  if (error is! PostgrestException) return null;
  final text = error.message;
  switch (match) {
    case RpcErrorMatch.originForbidden:
      if (!text.contains('FORBIDDEN')) return null;
      return 'You do not have permission to do that.';
    case RpcErrorMatch.originNotFound:
      if (!text.contains('NOT_FOUND')) return null;
      return 'Not found.';
    case RpcErrorMatch.originValidation:
    case RpcErrorMatch.notFoundPrefix:
    case RpcErrorMatch.duplicateStoryKey:
    case RpcErrorMatch.missingCoverColumn:
    case RpcErrorMatch.storyPeopleDuplicate:
      return null;
  }
}

String? _originValidation(Object error) {
  if (error is! PostgrestException) return null;
  final text = error.message;
  if (!text.contains('VALIDATION')) return null;
  const marker = 'VALIDATION: ';
  final index = text.indexOf(marker);
  if (index < 0) return text;
  return text.substring(index + marker.length).trim();
}

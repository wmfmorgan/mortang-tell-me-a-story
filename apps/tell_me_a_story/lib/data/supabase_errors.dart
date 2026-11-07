import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// SQL raises catalog errors as `PREFIX: detail` (§12 error catalog).
const _catalogPrefixes = <String, AppErrorCode>{
  'NOT_FOUND:': AppErrorCode.notFound,
  'FORBIDDEN:': AppErrorCode.forbidden,
  'VALIDATION:': AppErrorCode.validation,
  'INVITE_INVALID:': AppErrorCode.inviteInvalid,
};

/// A catalog [error] as an [AppException]; null for any other message.
AppException? appExceptionFromPostgrest(PostgrestException error) {
  final trimmed = error.message.trim();
  for (final entry in _catalogPrefixes.entries) {
    if (!trimmed.startsWith(entry.key)) continue;
    final detail = trimmed.substring(entry.key.length).trim();
    return AppException(
      code: entry.value,
      message: detail.isEmpty ? trimmed : detail,
    );
  }
  return null;
}

/// Runs a PostgREST [call]. Catalog errors are rethrown as [AppException];
/// every other error is rethrown unchanged.
Future<T> withAppErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PostgrestException catch (error) {
    final mapped = appExceptionFromPostgrest(error);
    if (mapped == null) rethrow;
    throw mapped;
  }
}

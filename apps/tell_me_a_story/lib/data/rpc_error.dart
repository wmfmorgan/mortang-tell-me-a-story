import 'package:supabase_flutter/supabase_flutter.dart';

/// The four prefixes a handled database failure may start with.
enum RpcErrorPrefix { notFound, forbidden, validation, inviteInvalid }

/// Detail after one of the four RPC prefixes, or null when none starts it.
String? mapRpcError(Object error) {
  if (error is! PostgrestException) return null;
  final trimmed = error.message.trim();
  const prefixes = <String>[
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

/// Which of the four prefixes starts [error], or null.
RpcErrorPrefix? rpcErrorPrefix(Object error) {
  if (error is! PostgrestException) return null;
  final trimmed = error.message.trim();
  if (trimmed.startsWith('NOT_FOUND:')) return RpcErrorPrefix.notFound;
  if (trimmed.startsWith('FORBIDDEN:')) return RpcErrorPrefix.forbidden;
  if (trimmed.startsWith('VALIDATION:')) return RpcErrorPrefix.validation;
  if (trimmed.startsWith('INVITE_INVALID:')) {
    return RpcErrorPrefix.inviteInvalid;
  }
  return null;
}

/// True when [error] is that SQLSTATE and names that exact quoted constraint.
bool rpcConstraintViolation(Object error, String sqlstate, String constraint) {
  if (error is! PostgrestException) return false;
  if (error.code != sqlstate) return false;
  final quoted = '"$constraint"';
  return error.message.split(quoted).length > 1;
}

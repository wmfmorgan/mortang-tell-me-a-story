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
    return detail.isEmpty ? null : detail;
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
  return error.message.contains(quoted);
}

/// Wire codes from `supabase/functions/_shared/error_codes.ts`, in that order.
enum EdgeErrorCode {
  notFound('NOT_FOUND'),
  forbidden('FORBIDDEN'),
  validation('VALIDATION'),
  inviteInvalid('INVITE_INVALID'),
  authRequired('AUTH_REQUIRED');

  const EdgeErrorCode(this.wire);

  final String wire;
}

/// Edge-function failure a screen can switch on.
class EdgeError {
  const EdgeError({required this.code, required this.message});

  final EdgeErrorCode code;
  final String message;
}

/// Reads a [FunctionException] or a decoded edge body.
///
/// An exact wire string becomes [EdgeErrorCode]. Anything else is
/// [EdgeErrorCode.validation]. [EdgeError.message] is the body's message
/// when the code matched and that message is a non-empty [String].
EdgeError edgeError(Object errorOrBody) {
  final raw = errorOrBody is FunctionException
      ? errorOrBody.details
      : errorOrBody;
  final body = raw is Map ? Map<Object?, Object?>.from(raw) : null;
  final code = _edgeErrorCode(body?['code']);
  final message = body?['message'];
  final shown = code != null && message is String && message.isNotEmpty
      ? message
      : 'Try again';
  return EdgeError(code: code ?? EdgeErrorCode.validation, message: shown);
}

EdgeErrorCode? _edgeErrorCode(Object? raw) {
  return switch (raw) {
    'NOT_FOUND' => EdgeErrorCode.notFound,
    'FORBIDDEN' => EdgeErrorCode.forbidden,
    'VALIDATION' => EdgeErrorCode.validation,
    'INVITE_INVALID' => EdgeErrorCode.inviteInvalid,
    'AUTH_REQUIRED' => EdgeErrorCode.authRequired,
    _ => null,
  };
}

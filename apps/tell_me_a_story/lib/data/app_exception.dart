/// Expected gateway failures. `withServerErrors`
/// (data/server/server_errors.dart) maps the server's generated `AppErrorCode`
/// (apps/server/lib/src/models/app_error_code.spy.yaml) onto this enum; see
/// docs/archive/migration/endpoint-contract.md §2.1. [unauthenticated]
/// corresponds to the server's `authRequired`.
enum AppErrorCode {
  notFound,
  forbidden,
  validation,
  inviteInvalid,
  unauthenticated,
}

/// An expected failure whose [message] is user-facing copy.
class AppException implements Exception {
  const AppException({required this.code, required this.message});

  final AppErrorCode code;
  final String message;

  @override
  String toString() => 'AppException(${code.name}: $message)';
}

/// [AppException.message] for an expected gateway failure, or null for any
/// other error (callers show their generic sentence).
String? appErrorMessage(Object error) =>
    error is AppException ? error.message : null;

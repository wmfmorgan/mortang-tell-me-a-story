/// Expected gateway failures. Mirrors the server `AppErrorCode`
/// (docs/migration/endpoint-contract.md §2.1) for the codes the Supabase
/// backend produces today, plus [unauthenticated] for calls made without a
/// session.
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

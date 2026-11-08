import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/photos_api.dart'
    show StorageFailedException;

/// Runs a server call and turns the server's errors into the client's, so
/// features keep catching the client [AppException] and the photo
/// exceptions. Anything else (network failures, bugs) passes through.
Future<T> withServerErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on server.AppException catch (e, stackTrace) {
    Error.throwWithStackTrace(clientError(e), stackTrace);
  } on server.ServerpodClientUnauthorized catch (_, stackTrace) {
    Error.throwWithStackTrace(
      const AppException(
        code: AppErrorCode.unauthenticated,
        message: 'Sign-in required',
      ),
      stackTrace,
    );
  }
}

/// The client error for a server [AppException][server.AppException].
Object clientError(server.AppException e) => switch (e.code) {
  server.AppErrorCode.authRequired => AppException(
    code: AppErrorCode.unauthenticated,
    message: e.message,
  ),
  server.AppErrorCode.forbidden => AppException(
    code: AppErrorCode.forbidden,
    message: e.message,
  ),
  server.AppErrorCode.notFound => AppException(
    code: AppErrorCode.notFound,
    message: e.message,
  ),
  server.AppErrorCode.validation || server.AppErrorCode.conflict =>
    AppException(code: AppErrorCode.validation, message: e.message),
  server.AppErrorCode.inviteInvalid ||
  server.AppErrorCode.inviteAccepted ||
  server.AppErrorCode.inviteExpired => AppException(
    code: AppErrorCode.inviteInvalid,
    message: e.message,
  ),
  server.AppErrorCode.photoCap => StateError('PHOTO_CAP'),
  server.AppErrorCode.storageFailed => StorageFailedException(cause: e),
};

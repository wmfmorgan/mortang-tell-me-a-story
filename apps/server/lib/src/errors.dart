import 'generated/protocol.dart';

/// Shorthands for the [AppException]s endpoints throw. Messages follow the
/// business-rules.md §5.2 catalogue; never put raw database text in them.
AppException forbidden([String message = "You don't have access to that."]) =>
    AppException(code: AppErrorCode.forbidden, message: message);

AppException notFound(String message) =>
    AppException(code: AppErrorCode.notFound, message: message);

AppException validation(String message) =>
    AppException(code: AppErrorCode.validation, message: message);

AppException conflict(String message) =>
    AppException(code: AppErrorCode.conflict, message: message);

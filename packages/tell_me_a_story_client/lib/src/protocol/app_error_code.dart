/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Machine-readable error code carried by [AppException]. Stored by name.
enum AppErrorCode implements _isc.SerializableModel {
  authRequired,
  forbidden,
  notFound,
  validation,
  conflict,
  inviteInvalid,
  inviteAccepted,
  inviteExpired,
  photoCap,
  storageFailed;

  static AppErrorCode fromJson(String name) {
    switch (name) {
      case 'authRequired':
        return AppErrorCode.authRequired;
      case 'forbidden':
        return AppErrorCode.forbidden;
      case 'notFound':
        return AppErrorCode.notFound;
      case 'validation':
        return AppErrorCode.validation;
      case 'conflict':
        return AppErrorCode.conflict;
      case 'inviteInvalid':
        return AppErrorCode.inviteInvalid;
      case 'inviteAccepted':
        return AppErrorCode.inviteAccepted;
      case 'inviteExpired':
        return AppErrorCode.inviteExpired;
      case 'photoCap':
        return AppErrorCode.photoCap;
      case 'storageFailed':
        return AppErrorCode.storageFailed;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AppErrorCode"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}

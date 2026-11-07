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
import 'package:serverpod/serverpod.dart' as _is;

/// Single error envelope for every endpoint.
/// code: auth_required | forbidden | not_found | validation | conflict |
///       invite_invalid | invite_accepted | invite_expired
abstract class AppException
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  AppException._({
    required this.code,
    required this.message,
  });

  factory AppException({
    required String code,
    required String message,
  }) = _AppExceptionImpl;

  factory AppException.fromJson(Map<String, dynamic> jsonSerialization) {
    return AppException(
      code: jsonSerialization['code'] as String,
      message: jsonSerialization['message'] as String,
    );
  }

  String code;

  String message;

  /// Returns a shallow copy of this [AppException]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AppException copyWith({
    String? code,
    String? message,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AppException',
      'code': code,
      'message': message,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AppException',
      'code': code,
      'message': message,
    };
  }

  @override
  String toString() {
    return 'AppException(code: $code, message: $message)';
  }
}

class _AppExceptionImpl extends AppException {
  _AppExceptionImpl({
    required String code,
    required String message,
  }) : super._(
         code: code,
         message: message,
       );

  /// Returns a shallow copy of this [AppException]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AppException copyWith({
    String? code,
    String? message,
  }) {
    return AppException(
      code: code ?? this.code,
      message: message ?? this.message,
    );
  }
}

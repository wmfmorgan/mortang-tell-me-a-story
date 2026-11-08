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

/// Returned by FamilyEndpoint.startCoverUpload.
abstract class CoverUploadTicketDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CoverUploadTicketDto._({
    required this.key,
    required this.uploadDescription,
  });

  factory CoverUploadTicketDto({
    required String key,
    required String uploadDescription,
  }) = _CoverUploadTicketDtoImpl;

  factory CoverUploadTicketDto.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return CoverUploadTicketDto(
      key: jsonSerialization['key'] as String,
      uploadDescription: jsonSerialization['uploadDescription'] as String,
    );
  }

  String key;

  String uploadDescription;

  /// Returns a shallow copy of this [CoverUploadTicketDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CoverUploadTicketDto copyWith({
    String? key,
    String? uploadDescription,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CoverUploadTicketDto',
      'key': key,
      'uploadDescription': uploadDescription,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CoverUploadTicketDto',
      'key': key,
      'uploadDescription': uploadDescription,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _CoverUploadTicketDtoImpl extends CoverUploadTicketDto {
  _CoverUploadTicketDtoImpl({
    required String key,
    required String uploadDescription,
  }) : super._(
         key: key,
         uploadDescription: uploadDescription,
       );

  /// Returns a shallow copy of this [CoverUploadTicketDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CoverUploadTicketDto copyWith({
    String? key,
    String? uploadDescription,
  }) {
    return CoverUploadTicketDto(
      key: key ?? this.key,
      uploadDescription: uploadDescription ?? this.uploadDescription,
    );
  }
}

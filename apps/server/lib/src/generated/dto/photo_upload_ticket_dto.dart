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

/// Returned by PhotoEndpoint.startUpload; uploadDescription feeds the client FileUploader.
abstract class PhotoUploadTicketDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PhotoUploadTicketDto._({
    required this.photoId,
    required this.key,
    required this.uploadDescription,
  });

  factory PhotoUploadTicketDto({
    required _is.UuidValue photoId,
    required String key,
    required String uploadDescription,
  }) = _PhotoUploadTicketDtoImpl;

  factory PhotoUploadTicketDto.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PhotoUploadTicketDto(
      photoId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['photoId'],
      ),
      key: jsonSerialization['key'] as String,
      uploadDescription: jsonSerialization['uploadDescription'] as String,
    );
  }

  _is.UuidValue photoId;

  String key;

  String uploadDescription;

  /// Returns a shallow copy of this [PhotoUploadTicketDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PhotoUploadTicketDto copyWith({
    _is.UuidValue? photoId,
    String? key,
    String? uploadDescription,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PhotoUploadTicketDto',
      'photoId': photoId.toJson(),
      'key': key,
      'uploadDescription': uploadDescription,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PhotoUploadTicketDto',
      'photoId': photoId.toJson(),
      'key': key,
      'uploadDescription': uploadDescription,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PhotoUploadTicketDtoImpl extends PhotoUploadTicketDto {
  _PhotoUploadTicketDtoImpl({
    required _is.UuidValue photoId,
    required String key,
    required String uploadDescription,
  }) : super._(
         photoId: photoId,
         key: key,
         uploadDescription: uploadDescription,
       );

  /// Returns a shallow copy of this [PhotoUploadTicketDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PhotoUploadTicketDto copyWith({
    _is.UuidValue? photoId,
    String? key,
    String? uploadDescription,
  }) {
    return PhotoUploadTicketDto(
      photoId: photoId ?? this.photoId,
      key: key ?? this.key,
      uploadDescription: uploadDescription ?? this.uploadDescription,
    );
  }
}

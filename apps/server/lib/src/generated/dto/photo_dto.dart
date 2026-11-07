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

/// A story photo. familyId is derived from the story, not stored.
abstract class PhotoDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PhotoDto._({
    required this.id,
    required this.storyId,
    required this.familyId,
    this.uploaderId,
    required this.originalKey,
    this.editedKey,
    required this.editVersion,
    required this.sortOrder,
  });

  factory PhotoDto({
    required _is.UuidValue id,
    required _is.UuidValue storyId,
    required _is.UuidValue familyId,
    _is.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    required int editVersion,
    required int sortOrder,
  }) = _PhotoDtoImpl;

  factory PhotoDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PhotoDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      uploaderId: jsonSerialization['uploaderId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['uploaderId'],
            ),
      originalKey: jsonSerialization['originalKey'] as String,
      editedKey: jsonSerialization['editedKey'] as String?,
      editVersion: jsonSerialization['editVersion'] as int,
      sortOrder: jsonSerialization['sortOrder'] as int,
    );
  }

  _is.UuidValue id;

  _is.UuidValue storyId;

  _is.UuidValue familyId;

  _is.UuidValue? uploaderId;

  String originalKey;

  String? editedKey;

  int editVersion;

  int sortOrder;

  /// Returns a shallow copy of this [PhotoDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PhotoDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? storyId,
    _is.UuidValue? familyId,
    _is.UuidValue? uploaderId = const _is.$UndefinedUuidValue(),
    String? originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PhotoDto',
      'id': id.toJson(),
      'storyId': storyId.toJson(),
      'familyId': familyId.toJson(),
      if (uploaderId != null) 'uploaderId': uploaderId?.toJson(),
      'originalKey': originalKey,
      if (editedKey != null) 'editedKey': editedKey,
      'editVersion': editVersion,
      'sortOrder': sortOrder,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PhotoDto',
      'id': id.toJson(),
      'storyId': storyId.toJson(),
      'familyId': familyId.toJson(),
      if (uploaderId != null) 'uploaderId': uploaderId?.toJson(),
      'originalKey': originalKey,
      if (editedKey != null) 'editedKey': editedKey,
      'editVersion': editVersion,
      'sortOrder': sortOrder,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PhotoDtoImpl extends PhotoDto {
  _PhotoDtoImpl({
    required _is.UuidValue id,
    required _is.UuidValue storyId,
    required _is.UuidValue familyId,
    _is.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    required int editVersion,
    required int sortOrder,
  }) : super._(
         id: id,
         storyId: storyId,
         familyId: familyId,
         uploaderId: uploaderId,
         originalKey: originalKey,
         editedKey: editedKey,
         editVersion: editVersion,
         sortOrder: sortOrder,
       );

  /// Returns a shallow copy of this [PhotoDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PhotoDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? storyId,
    _is.UuidValue? familyId,
    _is.UuidValue? uploaderId = const _is.$UndefinedUuidValue(),
    String? originalKey,
    Object? editedKey = _Undefined,
    int? editVersion,
    int? sortOrder,
  }) {
    return PhotoDto(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      familyId: familyId ?? this.familyId,
      uploaderId: uploaderId is _is.UndefinedSentinel
          ? this.uploaderId
          : uploaderId,
      originalKey: originalKey ?? this.originalKey,
      editedKey: editedKey is String? ? editedKey : this.editedKey,
      editVersion: editVersion ?? this.editVersion,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

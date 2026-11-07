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

/// A story photo. familyId is derived from the story, not stored.
abstract class PhotoDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
    required _isc.UuidValue id,
    required _isc.UuidValue storyId,
    required _isc.UuidValue familyId,
    _isc.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    required int editVersion,
    required int sortOrder,
  }) = _PhotoDtoImpl;

  factory PhotoDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return PhotoDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      uploaderId: jsonSerialization['uploaderId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['uploaderId'],
            ),
      originalKey: jsonSerialization['originalKey'] as String,
      editedKey: jsonSerialization['editedKey'] as String?,
      editVersion: jsonSerialization['editVersion'] as int,
      sortOrder: jsonSerialization['sortOrder'] as int,
    );
  }

  _isc.UuidValue id;

  _isc.UuidValue storyId;

  _isc.UuidValue familyId;

  _isc.UuidValue? uploaderId;

  String originalKey;

  String? editedKey;

  int editVersion;

  int sortOrder;

  /// Returns a shallow copy of this [PhotoDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PhotoDto copyWith({
    _isc.UuidValue? id,
    _isc.UuidValue? storyId,
    _isc.UuidValue? familyId,
    _isc.UuidValue? uploaderId = const _isc.$UndefinedUuidValue(),
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
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PhotoDtoImpl extends PhotoDto {
  _PhotoDtoImpl({
    required _isc.UuidValue id,
    required _isc.UuidValue storyId,
    required _isc.UuidValue familyId,
    _isc.UuidValue? uploaderId,
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
  @_isc.useResult
  @override
  PhotoDto copyWith({
    _isc.UuidValue? id,
    _isc.UuidValue? storyId,
    _isc.UuidValue? familyId,
    _isc.UuidValue? uploaderId = const _isc.$UndefinedUuidValue(),
    String? originalKey,
    Object? editedKey = _Undefined,
    int? editVersion,
    int? sortOrder,
  }) {
    return PhotoDto(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      familyId: familyId ?? this.familyId,
      uploaderId: uploaderId is _isc.UndefinedSentinel
          ? this.uploaderId
          : uploaderId,
      originalKey: originalKey ?? this.originalKey,
      editedKey: editedKey is String? ? editedKey : this.editedKey,
      editVersion: editVersion ?? this.editVersion,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

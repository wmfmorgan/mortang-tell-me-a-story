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

abstract class Photo
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Photo._({
    this.id,
    required this.storyId,
    this.uploaderId,
    required this.originalKey,
    this.editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) : editVersion = editVersion ?? 0,
       sortOrder = sortOrder ?? 0,
       createdAt = createdAt ?? DateTime.now();

  factory Photo({
    _isc.UuidValue? id,
    required _isc.UuidValue storyId,
    _isc.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) = _PhotoImpl;

  factory Photo.fromJson(Map<String, dynamic> jsonSerialization) {
    return Photo(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      uploaderId: jsonSerialization['uploaderId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['uploaderId'],
            ),
      originalKey: jsonSerialization['originalKey'] as String,
      editedKey: jsonSerialization['editedKey'] as String?,
      editVersion: jsonSerialization['editVersion'] as int?,
      sortOrder: jsonSerialization['sortOrder'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  _isc.UuidValue storyId;

  /// Uploader may delete own photo (story_reader_page.dart:1017).
  _isc.UuidValue? uploaderId;

  /// families/{familyId}/stories/{storyId}/photos/{photoId}/original.{jpg|png|webp}
  String originalKey;

  /// families/{familyId}/stories/{storyId}/photos/{photoId}/edited-{editVersion}.jpg
  String? editedKey;

  /// Optimistic-concurrency counter; +1 on every save AND reset of an edit.
  int editVersion;

  int sortOrder;

  DateTime createdAt;

  /// Returns a shallow copy of this [Photo]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Photo copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? storyId,
    _isc.UuidValue? uploaderId = const _isc.$UndefinedUuidValue(),
    String? originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Photo',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (uploaderId != null) 'uploaderId': uploaderId?.toJson(),
      'originalKey': originalKey,
      if (editedKey != null) 'editedKey': editedKey,
      'editVersion': editVersion,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Photo',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (uploaderId != null) 'uploaderId': uploaderId?.toJson(),
      'originalKey': originalKey,
      if (editedKey != null) 'editedKey': editedKey,
      'editVersion': editVersion,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PhotoImpl extends Photo {
  _PhotoImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue storyId,
    _isc.UuidValue? uploaderId,
    required String originalKey,
    String? editedKey,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) : super._(
         id: id,
         storyId: storyId,
         uploaderId: uploaderId,
         originalKey: originalKey,
         editedKey: editedKey,
         editVersion: editVersion,
         sortOrder: sortOrder,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Photo]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Photo copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? storyId,
    _isc.UuidValue? uploaderId = const _isc.$UndefinedUuidValue(),
    String? originalKey,
    Object? editedKey = _Undefined,
    int? editVersion,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Photo(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      storyId: storyId ?? this.storyId,
      uploaderId: uploaderId is _isc.UndefinedSentinel
          ? this.uploaderId
          : uploaderId,
      originalKey: originalKey ?? this.originalKey,
      editedKey: editedKey is String? ? editedKey : this.editedKey,
      editVersion: editVersion ?? this.editVersion,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

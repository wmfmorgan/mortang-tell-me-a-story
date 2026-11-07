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

import 'note_kind.dart' as _ixhn57mr;

/// Comments and perspectives in one table.
abstract class StoryNote
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StoryNote._({
    this.id,
    required this.storyId,
    this.authorId,
    required this.kind,
    required this.body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory StoryNote({
    _isc.UuidValue? id,
    required _isc.UuidValue storyId,
    _isc.UuidValue? authorId,
    required _ixhn57mr.NoteKind kind,
    required String body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoryNoteImpl;

  factory StoryNote.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryNote(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      authorId: jsonSerialization['authorId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['authorId']),
      kind: _ixhn57mr.NoteKind.fromJson((jsonSerialization['kind'] as String)),
      body: jsonSerialization['body'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  _isc.UuidValue? id;

  _isc.UuidValue storyId;

  _isc.UuidValue? authorId;

  _ixhn57mr.NoteKind kind;

  String body;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [StoryNote]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StoryNote copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? storyId,
    _isc.UuidValue? authorId = const _isc.$UndefinedUuidValue(),
    _ixhn57mr.NoteKind? kind,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryNote',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      'kind': kind.toJson(),
      'body': body,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryNote',
      if (id != null) 'id': id?.toJson(),
      'storyId': storyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      'kind': kind.toJson(),
      'body': body,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _StoryNoteImpl extends StoryNote {
  _StoryNoteImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue storyId,
    _isc.UuidValue? authorId,
    required _ixhn57mr.NoteKind kind,
    required String body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         storyId: storyId,
         authorId: authorId,
         kind: kind,
         body: body,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [StoryNote]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StoryNote copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? storyId,
    _isc.UuidValue? authorId = const _isc.$UndefinedUuidValue(),
    _ixhn57mr.NoteKind? kind,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoryNote(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      storyId: storyId ?? this.storyId,
      authorId: authorId is _isc.UndefinedSentinel ? this.authorId : authorId,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

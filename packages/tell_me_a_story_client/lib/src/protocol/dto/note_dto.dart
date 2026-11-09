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
import '../note_kind.dart' as _ird4e221;

/// A comment or perspective. familyId is derived from the story. canDelete is computed for the caller (D4).
abstract class NoteDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  NoteDto._({
    required this.id,
    required this.storyId,
    required this.familyId,
    required this.kind,
    this.authorId,
    this.authorName,
    required this.body,
    required this.createdAt,
    required this.canDelete,
  });

  factory NoteDto({
    required _isc.UuidValue id,
    required _isc.UuidValue storyId,
    required _isc.UuidValue familyId,
    required _ird4e221.NoteKind kind,
    _isc.UuidValue? authorId,
    String? authorName,
    required String body,
    required DateTime createdAt,
    required bool canDelete,
  }) = _NoteDtoImpl;

  factory NoteDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return NoteDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      storyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['storyId'],
      ),
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      kind: _ird4e221.NoteKind.fromJson((jsonSerialization['kind'] as String)),
      authorId: jsonSerialization['authorId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['authorId']),
      authorName: jsonSerialization['authorName'] as String?,
      body: jsonSerialization['body'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      canDelete: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['canDelete'],
      ),
    );
  }

  _isc.UuidValue id;

  _isc.UuidValue storyId;

  _isc.UuidValue familyId;

  _ird4e221.NoteKind kind;

  _isc.UuidValue? authorId;

  String? authorName;

  String body;

  DateTime createdAt;

  bool canDelete;

  /// Returns a shallow copy of this [NoteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  NoteDto copyWith({
    _isc.UuidValue? id,
    _isc.UuidValue? storyId,
    _isc.UuidValue? familyId,
    _ird4e221.NoteKind? kind,
    _isc.UuidValue? authorId = const _isc.$UndefinedUuidValue(),
    String? authorName,
    String? body,
    DateTime? createdAt,
    bool? canDelete,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NoteDto',
      'id': id.toJson(),
      'storyId': storyId.toJson(),
      'familyId': familyId.toJson(),
      'kind': kind.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (authorName != null) 'authorName': authorName,
      'body': body,
      'createdAt': createdAt.toJson(),
      'canDelete': canDelete,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'NoteDto',
      'id': id.toJson(),
      'storyId': storyId.toJson(),
      'familyId': familyId.toJson(),
      'kind': kind.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (authorName != null) 'authorName': authorName,
      'body': body,
      'createdAt': createdAt.toJson(),
      'canDelete': canDelete,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NoteDtoImpl extends NoteDto {
  _NoteDtoImpl({
    required _isc.UuidValue id,
    required _isc.UuidValue storyId,
    required _isc.UuidValue familyId,
    required _ird4e221.NoteKind kind,
    _isc.UuidValue? authorId,
    String? authorName,
    required String body,
    required DateTime createdAt,
    required bool canDelete,
  }) : super._(
         id: id,
         storyId: storyId,
         familyId: familyId,
         kind: kind,
         authorId: authorId,
         authorName: authorName,
         body: body,
         createdAt: createdAt,
         canDelete: canDelete,
       );

  /// Returns a shallow copy of this [NoteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  NoteDto copyWith({
    _isc.UuidValue? id,
    _isc.UuidValue? storyId,
    _isc.UuidValue? familyId,
    _ird4e221.NoteKind? kind,
    _isc.UuidValue? authorId = const _isc.$UndefinedUuidValue(),
    Object? authorName = _Undefined,
    String? body,
    DateTime? createdAt,
    bool? canDelete,
  }) {
    return NoteDto(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      familyId: familyId ?? this.familyId,
      kind: kind ?? this.kind,
      authorId: authorId is _isc.UndefinedSentinel ? this.authorId : authorId,
      authorName: authorName is String? ? authorName : this.authorName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      canDelete: canDelete ?? this.canDelete,
    );
  }
}

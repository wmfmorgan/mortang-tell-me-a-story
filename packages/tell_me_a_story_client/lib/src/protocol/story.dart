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
import 'date_precision.dart' as _ilvyd2nu;
import 'story_status.dart' as _ixc1exsr;

abstract class Story
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Story._({
    this.id,
    required this.familyId,
    this.authorId,
    this.title,
    this.body,
    _ixc1exsr.StoryStatus? status,
    this.dateStart,
    this.dateEnd,
    this.datePrecision,
    this.placeId,
    this.publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : status = status ?? _ixc1exsr.StoryStatus.draft,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Story({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    _isc.UuidValue? authorId,
    String? title,
    String? body,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart,
    DateTime? dateEnd,
    _ilvyd2nu.DatePrecision? datePrecision,
    _isc.UuidValue? placeId,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _StoryImpl;

  factory Story.fromJson(Map<String, dynamic> jsonSerialization) {
    return Story(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      authorId: jsonSerialization['authorId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['authorId']),
      title: jsonSerialization['title'] as String?,
      body: jsonSerialization['body'] as String?,
      status: jsonSerialization['status'] == null
          ? null
          : _ixc1exsr.StoryStatus.fromJson(
              (jsonSerialization['status'] as String),
            ),
      dateStart: jsonSerialization['dateStart'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['dateStart']),
      dateEnd: jsonSerialization['dateEnd'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['dateEnd']),
      datePrecision: jsonSerialization['datePrecision'] == null
          ? null
          : _ilvyd2nu.DatePrecision.fromJson(
              (jsonSerialization['datePrecision'] as int),
            ),
      placeId: jsonSerialization['placeId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['placeId']),
      publishedAt: jsonSerialization['publishedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['publishedAt'],
            ),
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

  _isc.UuidValue familyId;

  /// Null only after the author's account is deleted.
  _isc.UuidValue? authorId;

  String? title;

  String? body;

  _ixc1exsr.StoryStatus status;

  /// UTC midnight. All three null (undated draft) or a valid span (CHECK stories_date_shape).
  DateTime? dateStart;

  DateTime? dateEnd;

  _ilvyd2nu.DatePrecision? datePrecision;

  _isc.UuidValue? placeId;

  DateTime? publishedAt;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Story copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    _isc.UuidValue? authorId = const _isc.$UndefinedUuidValue(),
    String? title,
    String? body,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart = const _isc.$UndefinedDateTime(),
    DateTime? dateEnd = const _isc.$UndefinedDateTime(),
    _ilvyd2nu.DatePrecision? datePrecision,
    _isc.UuidValue? placeId = const _isc.$UndefinedUuidValue(),
    DateTime? publishedAt = const _isc.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'status': status.toJson(),
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (publishedAt != null) 'publishedAt': publishedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id?.toJson(),
      'familyId': familyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'status': status.toJson(),
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (publishedAt != null) 'publishedAt': publishedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StoryImpl extends Story {
  _StoryImpl({
    _isc.UuidValue? id,
    required _isc.UuidValue familyId,
    _isc.UuidValue? authorId,
    String? title,
    String? body,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart,
    DateTime? dateEnd,
    _ilvyd2nu.DatePrecision? datePrecision,
    _isc.UuidValue? placeId,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         familyId: familyId,
         authorId: authorId,
         title: title,
         body: body,
         status: status,
         dateStart: dateStart,
         dateEnd: dateEnd,
         datePrecision: datePrecision,
         placeId: placeId,
         publishedAt: publishedAt,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Story copyWith({
    _isc.UuidValue? id = const _isc.$UndefinedUuidValue(),
    _isc.UuidValue? familyId,
    _isc.UuidValue? authorId = const _isc.$UndefinedUuidValue(),
    Object? title = _Undefined,
    Object? body = _Undefined,
    _ixc1exsr.StoryStatus? status,
    DateTime? dateStart = const _isc.$UndefinedDateTime(),
    DateTime? dateEnd = const _isc.$UndefinedDateTime(),
    Object? datePrecision = _Undefined,
    _isc.UuidValue? placeId = const _isc.$UndefinedUuidValue(),
    DateTime? publishedAt = const _isc.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Story(
      id: id is _isc.UndefinedSentinel ? this.id : id,
      familyId: familyId ?? this.familyId,
      authorId: authorId is _isc.UndefinedSentinel ? this.authorId : authorId,
      title: title is String? ? title : this.title,
      body: body is String? ? body : this.body,
      status: status ?? this.status,
      dateStart: dateStart is _isc.UndefinedSentinel
          ? this.dateStart
          : dateStart,
      dateEnd: dateEnd is _isc.UndefinedSentinel ? this.dateEnd : dateEnd,
      datePrecision: datePrecision is _ilvyd2nu.DatePrecision?
          ? datePrecision
          : this.datePrecision,
      placeId: placeId is _isc.UndefinedSentinel ? this.placeId : placeId,
      publishedAt: publishedAt is _isc.UndefinedSentinel
          ? this.publishedAt
          : publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

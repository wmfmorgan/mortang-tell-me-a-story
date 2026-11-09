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
import 'package:tell_me_a_story_server/src/generated/protocol.dart'
    as _ixxtsu57;
import '../date_precision.dart' as _irl0sv7o;
import '../dto/photo_ref_dto.dart' as _iqos4nch;
import '../dto/story_person_dto.dart' as _i34crsqe;
import '../story_status.dart' as _irz424ig;

/// A story with everything the timeline and reader show.
abstract class StoryDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StoryDto._({
    required this.id,
    required this.familyId,
    this.authorId,
    this.title,
    this.body,
    this.dateStart,
    this.dateEnd,
    this.datePrecision,
    required this.createdAt,
    this.placeId,
    this.placeLabel,
    this.placeAddress,
    required this.status,
    this.publishedAt,
    required this.people,
    required this.photos,
    this.authorName,
    this.authorAvatarKey,
    required this.commentCount,
    required this.perspectiveCount,
  });

  factory StoryDto({
    required _is.UuidValue id,
    required _is.UuidValue familyId,
    _is.UuidValue? authorId,
    String? title,
    String? body,
    DateTime? dateStart,
    DateTime? dateEnd,
    _irl0sv7o.DatePrecision? datePrecision,
    required DateTime createdAt,
    _is.UuidValue? placeId,
    String? placeLabel,
    String? placeAddress,
    required _irz424ig.StoryStatus status,
    DateTime? publishedAt,
    required List<_i34crsqe.StoryPersonDto> people,
    required List<_iqos4nch.PhotoRefDto> photos,
    String? authorName,
    String? authorAvatarKey,
    required int commentCount,
    required int perspectiveCount,
  }) = _StoryDtoImpl;

  factory StoryDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryDto(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      authorId: jsonSerialization['authorId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['authorId']),
      title: jsonSerialization['title'] as String?,
      body: jsonSerialization['body'] as String?,
      dateStart: jsonSerialization['dateStart'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['dateStart']),
      dateEnd: jsonSerialization['dateEnd'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['dateEnd']),
      datePrecision: jsonSerialization['datePrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['datePrecision'] as int),
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      placeId: jsonSerialization['placeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['placeId']),
      placeLabel: jsonSerialization['placeLabel'] as String?,
      placeAddress: jsonSerialization['placeAddress'] as String?,
      status: _irz424ig.StoryStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      publishedAt: jsonSerialization['publishedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['publishedAt'],
            ),
      people: _ixxtsu57.Protocol().deserialize<List<_i34crsqe.StoryPersonDto>>(
        jsonSerialization['people'],
      ),
      photos: _ixxtsu57.Protocol().deserialize<List<_iqos4nch.PhotoRefDto>>(
        jsonSerialization['photos'],
      ),
      authorName: jsonSerialization['authorName'] as String?,
      authorAvatarKey: jsonSerialization['authorAvatarKey'] as String?,
      commentCount: jsonSerialization['commentCount'] as int,
      perspectiveCount: jsonSerialization['perspectiveCount'] as int,
    );
  }

  _is.UuidValue id;

  _is.UuidValue familyId;

  _is.UuidValue? authorId;

  String? title;

  String? body;

  DateTime? dateStart;

  DateTime? dateEnd;

  _irl0sv7o.DatePrecision? datePrecision;

  DateTime createdAt;

  _is.UuidValue? placeId;

  String? placeLabel;

  String? placeAddress;

  _irz424ig.StoryStatus status;

  DateTime? publishedAt;

  List<_i34crsqe.StoryPersonDto> people;

  List<_iqos4nch.PhotoRefDto> photos;

  String? authorName;

  String? authorAvatarKey;

  int commentCount;

  int perspectiveCount;

  /// Returns a shallow copy of this [StoryDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StoryDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? familyId,
    _is.UuidValue? authorId = const _is.$UndefinedUuidValue(),
    String? title,
    String? body,
    DateTime? dateStart = const _is.$UndefinedDateTime(),
    DateTime? dateEnd = const _is.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? datePrecision,
    DateTime? createdAt,
    _is.UuidValue? placeId = const _is.$UndefinedUuidValue(),
    String? placeLabel,
    String? placeAddress,
    _irz424ig.StoryStatus? status,
    DateTime? publishedAt = const _is.$UndefinedDateTime(),
    List<_i34crsqe.StoryPersonDto>? people,
    List<_iqos4nch.PhotoRefDto>? photos,
    String? authorName,
    String? authorAvatarKey,
    int? commentCount,
    int? perspectiveCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryDto',
      'id': id.toJson(),
      'familyId': familyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      'createdAt': createdAt.toJson(),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (placeLabel != null) 'placeLabel': placeLabel,
      if (placeAddress != null) 'placeAddress': placeAddress,
      'status': status.toJson(),
      if (publishedAt != null) 'publishedAt': publishedAt?.toJson(),
      'people': people.toJson(valueToJson: (v) => v.toJson()),
      'photos': photos.toJson(valueToJson: (v) => v.toJson()),
      if (authorName != null) 'authorName': authorName,
      if (authorAvatarKey != null) 'authorAvatarKey': authorAvatarKey,
      'commentCount': commentCount,
      'perspectiveCount': perspectiveCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryDto',
      'id': id.toJson(),
      'familyId': familyId.toJson(),
      if (authorId != null) 'authorId': authorId?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      'createdAt': createdAt.toJson(),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (placeLabel != null) 'placeLabel': placeLabel,
      if (placeAddress != null) 'placeAddress': placeAddress,
      'status': status.toJson(),
      if (publishedAt != null) 'publishedAt': publishedAt?.toJson(),
      'people': people.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'photos': photos.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (authorName != null) 'authorName': authorName,
      if (authorAvatarKey != null) 'authorAvatarKey': authorAvatarKey,
      'commentCount': commentCount,
      'perspectiveCount': perspectiveCount,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StoryDtoImpl extends StoryDto {
  _StoryDtoImpl({
    required _is.UuidValue id,
    required _is.UuidValue familyId,
    _is.UuidValue? authorId,
    String? title,
    String? body,
    DateTime? dateStart,
    DateTime? dateEnd,
    _irl0sv7o.DatePrecision? datePrecision,
    required DateTime createdAt,
    _is.UuidValue? placeId,
    String? placeLabel,
    String? placeAddress,
    required _irz424ig.StoryStatus status,
    DateTime? publishedAt,
    required List<_i34crsqe.StoryPersonDto> people,
    required List<_iqos4nch.PhotoRefDto> photos,
    String? authorName,
    String? authorAvatarKey,
    required int commentCount,
    required int perspectiveCount,
  }) : super._(
         id: id,
         familyId: familyId,
         authorId: authorId,
         title: title,
         body: body,
         dateStart: dateStart,
         dateEnd: dateEnd,
         datePrecision: datePrecision,
         createdAt: createdAt,
         placeId: placeId,
         placeLabel: placeLabel,
         placeAddress: placeAddress,
         status: status,
         publishedAt: publishedAt,
         people: people,
         photos: photos,
         authorName: authorName,
         authorAvatarKey: authorAvatarKey,
         commentCount: commentCount,
         perspectiveCount: perspectiveCount,
       );

  /// Returns a shallow copy of this [StoryDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StoryDto copyWith({
    _is.UuidValue? id,
    _is.UuidValue? familyId,
    _is.UuidValue? authorId = const _is.$UndefinedUuidValue(),
    Object? title = _Undefined,
    Object? body = _Undefined,
    DateTime? dateStart = const _is.$UndefinedDateTime(),
    DateTime? dateEnd = const _is.$UndefinedDateTime(),
    Object? datePrecision = _Undefined,
    DateTime? createdAt,
    _is.UuidValue? placeId = const _is.$UndefinedUuidValue(),
    Object? placeLabel = _Undefined,
    Object? placeAddress = _Undefined,
    _irz424ig.StoryStatus? status,
    DateTime? publishedAt = const _is.$UndefinedDateTime(),
    List<_i34crsqe.StoryPersonDto>? people,
    List<_iqos4nch.PhotoRefDto>? photos,
    Object? authorName = _Undefined,
    Object? authorAvatarKey = _Undefined,
    int? commentCount,
    int? perspectiveCount,
  }) {
    return StoryDto(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      authorId: authorId is _is.UndefinedSentinel ? this.authorId : authorId,
      title: title is String? ? title : this.title,
      body: body is String? ? body : this.body,
      dateStart: dateStart is _is.UndefinedSentinel
          ? this.dateStart
          : dateStart,
      dateEnd: dateEnd is _is.UndefinedSentinel ? this.dateEnd : dateEnd,
      datePrecision: datePrecision is _irl0sv7o.DatePrecision?
          ? datePrecision
          : this.datePrecision,
      createdAt: createdAt ?? this.createdAt,
      placeId: placeId is _is.UndefinedSentinel ? this.placeId : placeId,
      placeLabel: placeLabel is String? ? placeLabel : this.placeLabel,
      placeAddress: placeAddress is String? ? placeAddress : this.placeAddress,
      status: status ?? this.status,
      publishedAt: publishedAt is _is.UndefinedSentinel
          ? this.publishedAt
          : publishedAt,
      people: people ?? this.people.map((e0) => e0.copyWith()).toList(),
      photos: photos ?? this.photos.map((e0) => e0.copyWith()).toList(),
      authorName: authorName is String? ? authorName : this.authorName,
      authorAvatarKey: authorAvatarKey is String?
          ? authorAvatarKey
          : this.authorAvatarKey,
      commentCount: commentCount ?? this.commentCount,
      perspectiveCount: perspectiveCount ?? this.perspectiveCount,
    );
  }
}

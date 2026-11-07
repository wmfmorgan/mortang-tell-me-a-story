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
import 'package:tell_me_a_story_client/src/protocol/protocol.dart' as _ipmlb5v5;

import '../date_precision.dart' as _irl0sv7o;

/// Draft input. personIds null = leave story_people alone.
abstract class StoryWriteDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StoryWriteDto._({
    this.dateStart,
    this.dateEnd,
    this.datePrecision,
    this.title,
    this.body,
    this.placeId,
    required this.clearPlace,
    this.personIds,
  });

  factory StoryWriteDto({
    DateTime? dateStart,
    DateTime? dateEnd,
    _irl0sv7o.DatePrecision? datePrecision,
    String? title,
    String? body,
    _isc.UuidValue? placeId,
    required bool clearPlace,
    List<_isc.UuidValue>? personIds,
  }) = _StoryWriteDtoImpl;

  factory StoryWriteDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryWriteDto(
      dateStart: jsonSerialization['dateStart'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['dateStart']),
      dateEnd: jsonSerialization['dateEnd'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['dateEnd']),
      datePrecision: jsonSerialization['datePrecision'] == null
          ? null
          : _irl0sv7o.DatePrecision.fromJson(
              (jsonSerialization['datePrecision'] as int),
            ),
      title: jsonSerialization['title'] as String?,
      body: jsonSerialization['body'] as String?,
      placeId: jsonSerialization['placeId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['placeId']),
      clearPlace: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['clearPlace'],
      ),
      personIds: jsonSerialization['personIds'] == null
          ? null
          : _ipmlb5v5.Protocol().deserialize<List<_isc.UuidValue>>(
              jsonSerialization['personIds'],
            ),
    );
  }

  DateTime? dateStart;

  DateTime? dateEnd;

  _irl0sv7o.DatePrecision? datePrecision;

  String? title;

  String? body;

  _isc.UuidValue? placeId;

  bool clearPlace;

  List<_isc.UuidValue>? personIds;

  /// Returns a shallow copy of this [StoryWriteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StoryWriteDto copyWith({
    DateTime? dateStart = const _isc.$UndefinedDateTime(),
    DateTime? dateEnd = const _isc.$UndefinedDateTime(),
    _irl0sv7o.DatePrecision? datePrecision,
    String? title,
    String? body,
    _isc.UuidValue? placeId = const _isc.$UndefinedUuidValue(),
    bool? clearPlace,
    List<_isc.UuidValue>? personIds =
        const _isc.$UndefinedList<_isc.UuidValue>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryWriteDto',
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (placeId != null) 'placeId': placeId?.toJson(),
      'clearPlace': clearPlace,
      if (personIds != null)
        'personIds': personIds?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryWriteDto',
      if (dateStart != null) 'dateStart': dateStart?.toJson(),
      if (dateEnd != null) 'dateEnd': dateEnd?.toJson(),
      if (datePrecision != null) 'datePrecision': datePrecision?.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (placeId != null) 'placeId': placeId?.toJson(),
      'clearPlace': clearPlace,
      if (personIds != null)
        'personIds': personIds?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StoryWriteDtoImpl extends StoryWriteDto {
  _StoryWriteDtoImpl({
    DateTime? dateStart,
    DateTime? dateEnd,
    _irl0sv7o.DatePrecision? datePrecision,
    String? title,
    String? body,
    _isc.UuidValue? placeId,
    required bool clearPlace,
    List<_isc.UuidValue>? personIds,
  }) : super._(
         dateStart: dateStart,
         dateEnd: dateEnd,
         datePrecision: datePrecision,
         title: title,
         body: body,
         placeId: placeId,
         clearPlace: clearPlace,
         personIds: personIds,
       );

  /// Returns a shallow copy of this [StoryWriteDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StoryWriteDto copyWith({
    DateTime? dateStart = const _isc.$UndefinedDateTime(),
    DateTime? dateEnd = const _isc.$UndefinedDateTime(),
    Object? datePrecision = _Undefined,
    Object? title = _Undefined,
    Object? body = _Undefined,
    _isc.UuidValue? placeId = const _isc.$UndefinedUuidValue(),
    bool? clearPlace,
    List<_isc.UuidValue>? personIds =
        const _isc.$UndefinedList<_isc.UuidValue>(),
  }) {
    return StoryWriteDto(
      dateStart: dateStart is _isc.UndefinedSentinel
          ? this.dateStart
          : dateStart,
      dateEnd: dateEnd is _isc.UndefinedSentinel ? this.dateEnd : dateEnd,
      datePrecision: datePrecision is _irl0sv7o.DatePrecision?
          ? datePrecision
          : this.datePrecision,
      title: title is String? ? title : this.title,
      body: body is String? ? body : this.body,
      placeId: placeId is _isc.UndefinedSentinel ? this.placeId : placeId,
      clearPlace: clearPlace ?? this.clearPlace,
      personIds: personIds is _isc.UndefinedSentinel
          ? this.personIds?.map((e0) => e0).toList()
          : personIds,
    );
  }
}

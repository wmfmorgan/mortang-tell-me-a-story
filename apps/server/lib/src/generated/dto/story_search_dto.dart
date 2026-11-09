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
import '../dto/search_sort.dart' as _ihboepwu;

/// StoryEndpoint.search input (endpoint-contract.md, search semantics). Pass text '' for no text.
abstract class StorySearchDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StorySearchDto._({
    required this.familyId,
    required this.text,
    required this.personIds,
    this.placeId,
    this.rangeStart,
    this.rangeEnd,
    required this.decades,
    required this.sort,
  });

  factory StorySearchDto({
    required _is.UuidValue familyId,
    required String text,
    required List<_is.UuidValue> personIds,
    _is.UuidValue? placeId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    required List<int> decades,
    required _ihboepwu.SearchSort sort,
  }) = _StorySearchDtoImpl;

  factory StorySearchDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StorySearchDto(
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      text: jsonSerialization['text'] as String,
      personIds: _ixxtsu57.Protocol().deserialize<List<_is.UuidValue>>(
        jsonSerialization['personIds'],
      ),
      placeId: jsonSerialization['placeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['placeId']),
      rangeStart: jsonSerialization['rangeStart'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['rangeStart']),
      rangeEnd: jsonSerialization['rangeEnd'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['rangeEnd']),
      decades: _ixxtsu57.Protocol().deserialize<List<int>>(
        jsonSerialization['decades'],
      ),
      sort: _ihboepwu.SearchSort.fromJson(
        (jsonSerialization['sort'] as String),
      ),
    );
  }

  _is.UuidValue familyId;

  String text;

  List<_is.UuidValue> personIds;

  _is.UuidValue? placeId;

  DateTime? rangeStart;

  DateTime? rangeEnd;

  List<int> decades;

  _ihboepwu.SearchSort sort;

  /// Returns a shallow copy of this [StorySearchDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StorySearchDto copyWith({
    _is.UuidValue? familyId,
    String? text,
    List<_is.UuidValue>? personIds,
    _is.UuidValue? placeId = const _is.$UndefinedUuidValue(),
    DateTime? rangeStart = const _is.$UndefinedDateTime(),
    DateTime? rangeEnd = const _is.$UndefinedDateTime(),
    List<int>? decades,
    _ihboepwu.SearchSort? sort,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StorySearchDto',
      'familyId': familyId.toJson(),
      'text': text,
      'personIds': personIds.toJson(valueToJson: (v) => v.toJson()),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (rangeStart != null) 'rangeStart': rangeStart?.toJson(),
      if (rangeEnd != null) 'rangeEnd': rangeEnd?.toJson(),
      'decades': decades.toJson(),
      'sort': sort.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StorySearchDto',
      'familyId': familyId.toJson(),
      'text': text,
      'personIds': personIds.toJson(valueToJson: (v) => v.toJson()),
      if (placeId != null) 'placeId': placeId?.toJson(),
      if (rangeStart != null) 'rangeStart': rangeStart?.toJson(),
      if (rangeEnd != null) 'rangeEnd': rangeEnd?.toJson(),
      'decades': decades.toJson(),
      'sort': sort.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StorySearchDtoImpl extends StorySearchDto {
  _StorySearchDtoImpl({
    required _is.UuidValue familyId,
    required String text,
    required List<_is.UuidValue> personIds,
    _is.UuidValue? placeId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    required List<int> decades,
    required _ihboepwu.SearchSort sort,
  }) : super._(
         familyId: familyId,
         text: text,
         personIds: personIds,
         placeId: placeId,
         rangeStart: rangeStart,
         rangeEnd: rangeEnd,
         decades: decades,
         sort: sort,
       );

  /// Returns a shallow copy of this [StorySearchDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StorySearchDto copyWith({
    _is.UuidValue? familyId,
    String? text,
    List<_is.UuidValue>? personIds,
    _is.UuidValue? placeId = const _is.$UndefinedUuidValue(),
    DateTime? rangeStart = const _is.$UndefinedDateTime(),
    DateTime? rangeEnd = const _is.$UndefinedDateTime(),
    List<int>? decades,
    _ihboepwu.SearchSort? sort,
  }) {
    return StorySearchDto(
      familyId: familyId ?? this.familyId,
      text: text ?? this.text,
      personIds: personIds ?? this.personIds.map((e0) => e0).toList(),
      placeId: placeId is _is.UndefinedSentinel ? this.placeId : placeId,
      rangeStart: rangeStart is _is.UndefinedSentinel
          ? this.rangeStart
          : rangeStart,
      rangeEnd: rangeEnd is _is.UndefinedSentinel ? this.rangeEnd : rangeEnd,
      decades: decades ?? this.decades.map((e0) => e0).toList(),
      sort: sort ?? this.sort,
    );
  }
}

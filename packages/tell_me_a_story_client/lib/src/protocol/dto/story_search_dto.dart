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
import '../dto/search_sort.dart' as _ihboepwu;

/// StoryEndpoint.search input (endpoint-contract.md, search semantics). Pass text '' for no text.
abstract class StorySearchDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
    required _isc.UuidValue familyId,
    required String text,
    required List<_isc.UuidValue> personIds,
    _isc.UuidValue? placeId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    required List<int> decades,
    required _ihboepwu.SearchSort sort,
  }) = _StorySearchDtoImpl;

  factory StorySearchDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StorySearchDto(
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      text: jsonSerialization['text'] as String,
      personIds: _ipmlb5v5.Protocol().deserialize<List<_isc.UuidValue>>(
        jsonSerialization['personIds'],
      ),
      placeId: jsonSerialization['placeId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['placeId']),
      rangeStart: jsonSerialization['rangeStart'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['rangeStart'],
            ),
      rangeEnd: jsonSerialization['rangeEnd'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['rangeEnd']),
      decades: _ipmlb5v5.Protocol().deserialize<List<int>>(
        jsonSerialization['decades'],
      ),
      sort: _ihboepwu.SearchSort.fromJson(
        (jsonSerialization['sort'] as String),
      ),
    );
  }

  _isc.UuidValue familyId;

  String text;

  List<_isc.UuidValue> personIds;

  _isc.UuidValue? placeId;

  DateTime? rangeStart;

  DateTime? rangeEnd;

  List<int> decades;

  _ihboepwu.SearchSort sort;

  /// Returns a shallow copy of this [StorySearchDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StorySearchDto copyWith({
    _isc.UuidValue? familyId,
    String? text,
    List<_isc.UuidValue>? personIds,
    _isc.UuidValue? placeId = const _isc.$UndefinedUuidValue(),
    DateTime? rangeStart = const _isc.$UndefinedDateTime(),
    DateTime? rangeEnd = const _isc.$UndefinedDateTime(),
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
    return _isc.SerializationManager.encode(this);
  }
}

class _StorySearchDtoImpl extends StorySearchDto {
  _StorySearchDtoImpl({
    required _isc.UuidValue familyId,
    required String text,
    required List<_isc.UuidValue> personIds,
    _isc.UuidValue? placeId,
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
  @_isc.useResult
  @override
  StorySearchDto copyWith({
    _isc.UuidValue? familyId,
    String? text,
    List<_isc.UuidValue>? personIds,
    _isc.UuidValue? placeId = const _isc.$UndefinedUuidValue(),
    DateTime? rangeStart = const _isc.$UndefinedDateTime(),
    DateTime? rangeEnd = const _isc.$UndefinedDateTime(),
    List<int>? decades,
    _ihboepwu.SearchSort? sort,
  }) {
    return StorySearchDto(
      familyId: familyId ?? this.familyId,
      text: text ?? this.text,
      personIds: personIds ?? this.personIds.map((e0) => e0).toList(),
      placeId: placeId is _isc.UndefinedSentinel ? this.placeId : placeId,
      rangeStart: rangeStart is _isc.UndefinedSentinel
          ? this.rangeStart
          : rangeStart,
      rangeEnd: rangeEnd is _isc.UndefinedSentinel ? this.rangeEnd : rangeEnd,
      decades: decades ?? this.decades.map((e0) => e0).toList(),
      sort: sort ?? this.sort,
    );
  }
}

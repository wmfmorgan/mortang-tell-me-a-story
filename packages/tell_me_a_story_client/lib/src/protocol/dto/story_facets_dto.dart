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

import '../dto/decade_facet_dto.dart' as _iqq86m7g;
import '../dto/person_facet_dto.dart' as _iduhd325;
import '../dto/place_facet_dto.dart' as _i9t16hbm;

/// StoryEndpoint.facets result.
abstract class StoryFacetsDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StoryFacetsDto._({
    required this.decades,
    required this.people,
    required this.places,
  });

  factory StoryFacetsDto({
    required List<_iqq86m7g.DecadeFacetDto> decades,
    required List<_iduhd325.PersonFacetDto> people,
    required List<_i9t16hbm.PlaceFacetDto> places,
  }) = _StoryFacetsDtoImpl;

  factory StoryFacetsDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return StoryFacetsDto(
      decades: _ipmlb5v5.Protocol().deserialize<List<_iqq86m7g.DecadeFacetDto>>(
        jsonSerialization['decades'],
      ),
      people: _ipmlb5v5.Protocol().deserialize<List<_iduhd325.PersonFacetDto>>(
        jsonSerialization['people'],
      ),
      places: _ipmlb5v5.Protocol().deserialize<List<_i9t16hbm.PlaceFacetDto>>(
        jsonSerialization['places'],
      ),
    );
  }

  List<_iqq86m7g.DecadeFacetDto> decades;

  List<_iduhd325.PersonFacetDto> people;

  List<_i9t16hbm.PlaceFacetDto> places;

  /// Returns a shallow copy of this [StoryFacetsDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StoryFacetsDto copyWith({
    List<_iqq86m7g.DecadeFacetDto>? decades,
    List<_iduhd325.PersonFacetDto>? people,
    List<_i9t16hbm.PlaceFacetDto>? places,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StoryFacetsDto',
      'decades': decades.toJson(valueToJson: (v) => v.toJson()),
      'people': people.toJson(valueToJson: (v) => v.toJson()),
      'places': places.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StoryFacetsDto',
      'decades': decades.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'people': people.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'places': places.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _StoryFacetsDtoImpl extends StoryFacetsDto {
  _StoryFacetsDtoImpl({
    required List<_iqq86m7g.DecadeFacetDto> decades,
    required List<_iduhd325.PersonFacetDto> people,
    required List<_i9t16hbm.PlaceFacetDto> places,
  }) : super._(
         decades: decades,
         people: people,
         places: places,
       );

  /// Returns a shallow copy of this [StoryFacetsDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StoryFacetsDto copyWith({
    List<_iqq86m7g.DecadeFacetDto>? decades,
    List<_iduhd325.PersonFacetDto>? people,
    List<_i9t16hbm.PlaceFacetDto>? places,
  }) {
    return StoryFacetsDto(
      decades: decades ?? this.decades.map((e0) => e0.copyWith()).toList(),
      people: people ?? this.people.map((e0) => e0.copyWith()).toList(),
      places: places ?? this.places.map((e0) => e0.copyWith()).toList(),
    );
  }
}

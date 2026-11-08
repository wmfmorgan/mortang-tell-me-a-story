import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// Places are shared by every family in a tree (business-rules.md §2.4, §8
/// item 1). `familyId` parameters resolve the family's tree; the caller must
/// be a live member of a live family in that tree, and the family itself must
/// be live (D6b). Place rows are checked by their `treeId` (D8).
class PlaceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<List<PlaceDto>> list(Session session, UuidValue familyId) async {
    final treeId = await _readableTree(session, familyId);
    final rows = await Place.db.find(
      session,
      where: (t) => t.treeId.equals(treeId),
      orderByList: (t) => [t.label.asc(), t.id.asc()],
    );
    return rows.map(_dto).toList();
  }

  Future<List<PlaceDto>> favorites(Session session, UuidValue familyId) async {
    final treeId = await _readableTree(session, familyId);
    final rows = await Place.db.find(
      session,
      where: (t) => t.treeId.equals(treeId) & t.isFavorite.equals(true),
      orderByList: (t) => [t.label.asc(), t.id.asc()],
    );
    return rows.map(_dto).toList();
  }

  Future<List<PlaceDto>> recents(
    Session session,
    UuidValue familyId, {
    int limit = 10,
  }) async {
    final treeId = await _readableTree(session, familyId);
    final rows = await Place.db.find(
      session,
      where: (t) => t.treeId.equals(treeId) & t.lastUsedAt.notEquals(null),
      orderByList: (t) => [t.lastUsedAt.desc(), t.id.asc()],
      limit: limit.clamp(1, 100),
    );
    return rows.map(_dto).toList();
  }

  /// Creates a place in the family's tree, marked used now. A place with the
  /// same Mapbox id already in the tree is returned instead (schema-design.md
  /// §3.2, places).
  Future<PlaceDto> create(
    Session session,
    UuidValue familyId,
    PlaceInputDto input,
  ) async {
    final treeId = await _readableTree(session, familyId);
    final label = input.label.trim();
    final address = input.address.trim();
    if (label.isEmpty) throw validation('label is required');
    if (address.isEmpty) throw validation('address is required');
    final mapboxPlaceId = input.mapboxPlaceId?.trim();
    final mapboxId = mapboxPlaceId == null || mapboxPlaceId.isEmpty
        ? null
        : mapboxPlaceId;
    if (mapboxId != null) {
      final existing = await _byMapboxId(session, treeId, mapboxId);
      if (existing != null) return _dto(existing);
    }
    try {
      final row = await Place.db.insertRow(
        session,
        Place(
          treeId: treeId,
          label: label,
          address: address,
          lat: input.lat,
          lng: input.lng,
          mapboxPlaceId: mapboxId,
          isFavorite: input.isFavorite,
          lastUsedAt: DateTime.now().toUtc(),
        ),
      );
      return _dto(row);
    } on DatabaseQueryException catch (e) {
      if (e.code != '23505' || e.constraintName != 'places_tree_mapbox_uidx') {
        rethrow;
      }
      return _dto((await _byMapboxId(session, treeId, mapboxId!))!);
    }
  }

  Future<PlaceDto> markUsed(Session session, UuidValue placeId) async {
    final place = await _writablePlace(session, placeId);
    final row = await Place.db.updateRow(
      session,
      place.copyWith(lastUsedAt: DateTime.now().toUtc()),
      columns: (t) => [t.lastUsedAt],
    );
    return _dto(row);
  }

  Future<PlaceDto> setFavorite(
    Session session,
    UuidValue placeId,
    bool isFavorite,
  ) async {
    final place = await _writablePlace(session, placeId);
    final row = await Place.db.updateRow(
      session,
      place.copyWith(isFavorite: isFavorite),
      columns: (t) => [t.isFavorite],
    );
    return _dto(row);
  }

  Future<PlaceDto?> findByMapboxId(
    Session session,
    UuidValue familyId,
    String mapboxPlaceId,
  ) async {
    final treeId = await _readableTree(session, familyId);
    final row = await _byMapboxId(session, treeId, mapboxPlaceId.trim());
    return row == null ? null : _dto(row);
  }

  /// Null when the place doesn't exist or the caller can't read its tree.
  Future<PlaceDto?> get(Session session, UuidValue placeId) async {
    final place = await Place.db.findById(session, placeId);
    if (place == null || !await Authz(session).isTreeMemberOf(place.treeId)) {
      return null;
    }
    return _dto(place);
  }
}

/// The tree of live [familyId] when the caller reads it (member or tree
/// reader); otherwise FORBIDDEN, also for a missing or soft-deleted family.
Future<UuidValue> _readableTree(Session session, UuidValue familyId) async {
  final family = await Family.db.findById(session, familyId);
  if (family == null || !await Authz(session).isTreeReadable(familyId)) {
    throw forbidden();
  }
  return family.treeId;
}

/// [placeId] when the caller is a live member of a live family in its tree;
/// a missing place is refused the same way.
Future<Place> _writablePlace(Session session, UuidValue placeId) async {
  final place = await Place.db.findById(session, placeId);
  if (place == null || !await Authz(session).isTreeMemberOf(place.treeId)) {
    throw forbidden();
  }
  return place;
}

Future<Place?> _byMapboxId(
  Session session,
  UuidValue treeId,
  String mapboxPlaceId,
) => Place.db.findFirstRow(
  session,
  where: (t) => t.treeId.equals(treeId) & t.mapboxPlaceId.equals(mapboxPlaceId),
);

PlaceDto _dto(Place p) => PlaceDto(
  id: p.id!,
  treeId: p.treeId,
  label: p.label,
  address: p.address,
  lat: p.lat,
  lng: p.lng,
  mapboxPlaceId: p.mapboxPlaceId,
  isFavorite: p.isFavorite,
  lastUsedAt: p.lastUsedAt,
);

import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/features/search/domain/search_facets.dart';
import 'package:tell_me_a_story/features/search/domain/search_repository.dart';

part 'search_providers.g.dart';

/// The family being searched and what its published stories can be
/// filtered by. A null [familyId] means the user has no family yet.
typedef SearchScope = ({String? familyId, SearchFacets facets});

@riverpod
Future<SearchScope> searchScope(Ref ref) async {
  final familyId = await ref.watch(inviteRepositoryProvider).currentFamilyId();
  if (familyId == null) return (familyId: null, facets: const SearchFacets());
  final facets = await ref.watch(searchRepositoryProvider).facets(familyId);
  return (familyId: familyId, facets: facets);
}

/// Bytes of one result card's first photo.
@riverpod
Future<Uint8List> searchPhotoBytes(Ref ref, String path) =>
    ref.watch(photosRepositoryProvider).downloadBytes(path);

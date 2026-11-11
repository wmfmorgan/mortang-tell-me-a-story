import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:tell_me_a_story/features/search/domain/search_sort.dart';

part 'search_request.freezed.dart';

@freezed
abstract class SearchRequest with _$SearchRequest {
  const factory SearchRequest({
    required String familyId,
    @Default('') String text,
    @Default([]) List<String> personIds,
    String? placeId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    @Default([]) List<int> decades,
    @Default(SearchSort.relevant) SearchSort sort,
  }) = _SearchRequest;
}

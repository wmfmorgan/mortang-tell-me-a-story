import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'person_story_card.freezed.dart';

/// One published story on a person profile.
@freezed
abstract class PersonStoryCard with _$PersonStoryCard {
  const factory PersonStoryCard({
    required String id,
    required String title,
    required String whenLabel,
    String? place,
    @Default(0) int photoCount,
    Uint8List? thumbBytes,
  }) = _PersonStoryCard;
}

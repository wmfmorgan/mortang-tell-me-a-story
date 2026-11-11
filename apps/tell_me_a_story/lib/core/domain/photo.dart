import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo.freezed.dart';

const maxPhotosPerStory = 20;

/// A story photo. [storagePath] / [editedStoragePath] are the server's blob
/// keys, read back through `media.get`.
@freezed
abstract class Photo with _$Photo {
  const factory Photo({
    required String id,
    required String storyId,
    required String familyId,

    /// Null once the uploader's account is gone.
    required String? uploaderId,
    required String storagePath,
    String? editedStoragePath,
    @Default(0) int editVersion,
    required int sortOrder,
  }) = _Photo;

  const Photo._();

  String get effectiveStoragePath => editedStoragePath ?? storagePath;
}

/// Lowest [Photo.sortOrder] first, then id.
int comparePhotoOrder(Photo a, Photo b) {
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  return a.id.compareTo(b.id);
}

/// Puts [heroId] first and keeps the other photos in their previous order.
/// Sort orders are rewritten to 0..n-1.
List<Photo> photosWithHeroFirst(List<Photo> photos, String heroId) {
  final sorted = [...photos]..sort(comparePhotoOrder);
  final index = sorted.indexWhere((photo) => photo.id == heroId);
  if (index > 0) {
    final chosen = sorted.removeAt(index);
    sorted.insert(0, chosen);
  }
  return [
    for (var i = 0; i < sorted.length; i++)
      sorted[i].sortOrder == i
          ? sorted[i]
          : sorted[i].copyWith(
              editedStoragePath: sorted[i].editedStoragePath,
              sortOrder: i,
            ),
  ];
}

void ensurePhotoCap(int currentCount) {
  if (currentCount >= maxPhotosPerStory) {
    throw StateError('PHOTO_CAP');
  }
}

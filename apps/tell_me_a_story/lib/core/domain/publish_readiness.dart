import 'package:freezed_annotation/freezed_annotation.dart';

part 'publish_readiness.freezed.dart';

@freezed
abstract class PublishReadiness with _$PublishReadiness {
  const factory PublishReadiness({
    required bool hasTitle,
    required bool hasBody,
    required bool hasTimeframe,
    required bool hasPerson,

    /// Shown as a Drafts hint; a story publishes without a place.
    required bool hasPlace,
  }) = _PublishReadiness;

  const PublishReadiness._();

  bool get canPublish => hasTitle && hasBody && hasTimeframe && hasPerson;
}

PublishReadiness publishReadiness({
  required String? title,
  required String? body,
  required DateTime? timeframeStart,
  required Iterable<String> personIds,
  required String? placeId,
}) {
  return PublishReadiness(
    hasTitle: (title ?? '').trim().isNotEmpty,
    hasBody: (body ?? '').trim().isNotEmpty,
    hasTimeframe: timeframeStart != null,
    hasPerson: personIds.isNotEmpty,
    hasPlace: placeId != null && placeId.isNotEmpty,
  );
}

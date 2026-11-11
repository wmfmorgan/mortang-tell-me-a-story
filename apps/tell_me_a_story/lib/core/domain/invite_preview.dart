import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_preview.freezed.dart';

@freezed
abstract class InvitePreview with _$InvitePreview {
  const factory InvitePreview({
    required bool valid,
    String? familyId,
    String? familyName,
    String? inviterName,
  }) = _InvitePreview;
}

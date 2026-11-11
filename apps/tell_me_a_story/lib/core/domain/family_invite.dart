import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_invite.freezed.dart';

@freezed
abstract class FamilyInvite with _$FamilyInvite {
  const FamilyInvite._();

  const factory FamilyInvite({
    required String id,
    required String? email,
    required DateTime? expiresAt,
    DateTime? createdAt,

    /// When the invite was last emailed or resent.
    DateTime? lastSentAt,
  }) = _FamilyInvite;

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  /// [lastSentAt], else [createdAt], else [expiresAt] minus the 7-day window.
  DateTime? get sentAt {
    final sent = lastSentAt ?? createdAt;
    if (sent != null) return sent;
    final expiry = expiresAt;
    if (expiry == null) return null;
    return expiry.subtract(const Duration(days: 7));
  }
}

const _albumMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Month and day, for invite sent and expiry lines. No new package.
String albumMonthDay(DateTime value) {
  final local = value.toLocal();
  return '${_albumMonths[local.month - 1]} ${local.day}';
}

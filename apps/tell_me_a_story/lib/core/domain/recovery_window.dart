/// Soft-deleted families stay recoverable until this age. Matches the
/// security-definer check `deleted_at < now() - interval '60 days'`.
const recoveryWindow = Duration(days: 60);

/// True when [deletedAt] is still inside the recover window.
bool isInsideRecoveryWindow(DateTime deletedAt, [DateTime? now]) {
  final clock = (now ?? DateTime.now()).toUtc();
  return !deletedAt.toUtc().isBefore(clock.subtract(recoveryWindow));
}

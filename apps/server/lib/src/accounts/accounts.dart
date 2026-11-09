import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';

/// Trimmed and lower-cased, the form invite emails are compared in (D2).
String normalizeEmail(String email) => email.trim().toLowerCase();

/// The login email of [authUserId], normalized; null when the user has no
/// email login.
Future<String?> accountEmail(
  Session session,
  UuidValue authUserId, {
  Transaction? transaction,
}) async {
  final account = await EmailAccount.db.findFirstRow(
    session,
    where: (t) => t.authUserId.equals(authUserId),
    transaction: transaction,
  );
  return account == null ? null : normalizeEmail(account.email);
}

/// Name for a new linked person: the display name, else the email local
/// part, else `Member` (schema-design.md §3.2, createRoot).
String linkedPersonName({String? displayName, String? email}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final local = email?.split('@').first.trim() ?? '';
  if (local.isNotEmpty) return local;
  return 'Member';
}

/// The person linked to [userId] in tree [treeId]. Reuses the existing one
/// anywhere in the tree; otherwise creates one with [homeFamilyId] as its
/// home (createRoot, createBranch D6d, invite accept). The person's own email
/// stays null: the account email is never copied onto a person.
Future<Person> ensureLinkedPerson(
  Session session, {
  required UuidValue treeId,
  required UuidValue homeFamilyId,
  required UuidValue userId,
  required Transaction transaction,
}) async {
  final existing = await Person.db.findFirstRow(
    session,
    where: (t) => t.treeId.equals(treeId) & t.userId.equals(userId),
    transaction: transaction,
  );
  if (existing != null) return existing;
  final appUser = await AppUser.db.findFirstRow(
    session,
    where: (t) => t.authUserId.equals(userId),
    transaction: transaction,
  );
  final email = await accountEmail(session, userId, transaction: transaction);
  return Person.db.insertRow(
    session,
    Person(
      treeId: treeId,
      homeFamilyId: homeFamilyId,
      userId: userId,
      name: linkedPersonName(displayName: appUser?.displayName, email: email),
      createdById: userId,
    ),
    transaction: transaction,
  );
}

import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// Families, memberships and covers (business-rules.md §2.1, §2.2, §3.1–§3.3,
/// §3.5, §3.6; schema-design.md §3.2). Every write and member read needs a
/// live family (D6b); only `recover` and the steward reads `listStewarded`,
/// `directory` and `detail` reach a soft-deleted family.
class FamilyEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // ── create root ──────────────────────────────────────────────────────

  /// A new tree with one family; the caller is its owner and gets a linked
  /// person (business-rules.md §3.1).
  Future<UuidValue> createRoot(Session session, String name) async {
    final uid = Authz(session).requireUser();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw validation('name is required');
    return session.db.transaction((t) async {
      final tree = await Tree.db.insertRow(session, Tree(), transaction: t);
      final family = await Family.db.insertRow(
        session,
        Family(treeId: tree.id!, name: trimmed, createdById: uid),
        transaction: t,
      );
      await Membership.db.insertRow(
        session,
        Membership(
          familyId: family.id!,
          userId: uid,
          role: MembershipRole.owner,
        ),
        transaction: t,
      );
      await ensureLinkedPerson(
        session,
        treeId: tree.id!,
        homeFamilyId: family.id!,
        userId: uid,
        transaction: t,
      );
      return family.id!;
    });
  }
}

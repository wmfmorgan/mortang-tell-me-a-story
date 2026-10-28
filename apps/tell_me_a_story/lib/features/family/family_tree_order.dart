import 'package:flutter/widgets.dart';

import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';

/// Lower-cased name with surrounding space trimmed and one leading "The "
/// dropped (same rule as familyMonogram in family_role.dart).
String familySortKey(String name) {
  var key = name.trim().toLowerCase();
  if (key.startsWith('the ')) key = key.substring(4).trimLeft();
  return key;
}

/// Top level: A to Z by familySortKey, then id (stated tie-break).
int compareTopLevel(MemberFamily a, MemberFamily b) {
  final byName = familySortKey(a.name).compareTo(familySortKey(b.name));
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

/// Children: branchYear ascending, null last, then compareTopLevel
/// (name key, then id).
int compareChildren(MemberFamily a, MemberFamily b) {
  final ay = a.branchYear, by = b.branchYear;
  if (ay != by) {
    if (ay == null) return 1;
    if (by == null) return -1;
    return ay.compareTo(by);
  }
  return compareTopLevel(a, b);
}

class FamilyMenuRow {
  const FamilyMenuRow(this.family, this.depth);
  final MemberFamily family;
  final int depth; // 0 = top level
}

/// [families] is the caller's live list (listMine()). A family nests only
/// when its parent is in that list; otherwise it is top level. Every family
/// appears exactly once, even if parent links form a cycle.
List<FamilyMenuRow> nestFamilies(List<MemberFamily> families) {
  final byId = <String, MemberFamily>{};
  for (final f in families) {
    byId.putIfAbsent(f.id, () => f); // first one wins on a duplicate id
  }
  final roots = <MemberFamily>[];
  final children = <String, List<MemberFamily>>{};
  for (final f in byId.values) {
    final parent = f.parentFamilyId;
    if (parent == null || parent == f.id || !byId.containsKey(parent)) {
      roots.add(f); // orphan, self-parent or deleted/unknown parent
    } else {
      (children[parent] ??= <MemberFamily>[]).add(f);
    }
  }
  roots.sort(compareTopLevel);
  for (final list in children.values) {
    list.sort(compareChildren);
  }
  final out = <FamilyMenuRow>[];
  final visited = <String>{};
  void visit(MemberFamily f, int depth) {
    if (!visited.add(f.id)) return; // cycle guard
    out.add(FamilyMenuRow(f, depth));
    for (final c in children[f.id] ?? const <MemberFamily>[]) {
      visit(c, depth + 1);
    }
  }

  for (final r in roots) {
    visit(r, 0);
  }
  // Families only reachable through a cycle (A→B→A) were never visited:
  // list them at the top level, sorted, each with its own reachable subtree.
  final stranded = [
    for (final f in byId.values)
      if (!visited.contains(f.id)) f,
  ]..sort(compareTopLevel);
  for (final f in stranded) {
    visit(f, 0);
  }
  return out;
}

/// One 24px slot per level, each with a 1px albumSage line centred in it.
/// Rows stack with no gap, so each level's lines join into one line down
/// the left of that parent's indented block (UX l.56).
class FamilyIndentGuide extends StatelessWidget {
  const FamilyIndentGuide({
    super.key,
    required this.depth,
    required this.height,
    this.stopShort = false,
  });

  final int depth;
  final double height;

  /// End the sage line above the bottom of this slot so it does not run
  /// into the post-families divider.
  final bool stopShort;

  @override
  Widget build(BuildContext context) {
    if (depth <= 0) return const SizedBox.shrink();
    final lineHeight = stopShort && height > 12 ? height - 12 : height;
    return SizedBox(
      width: 24.0 * depth,
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < depth; i++)
            SizedBox(
              width: 24,
              height: height,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 1,
                  height: lineHeight,
                  child: const ColoredBox(color: albumSage),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

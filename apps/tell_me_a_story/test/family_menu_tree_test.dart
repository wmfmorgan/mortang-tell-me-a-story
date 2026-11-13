import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/features/family/family_tree_order.dart';

MemberFamily _family(
  String id,
  String name, {
  String? parent,
  int? year,
  String? role,
}) {
  return MemberFamily(
    id: id,
    name: name,
    parentFamilyId: parent,
    branchYear: year,
    role: role,
    createdAt: DateTime.utc(2020),
  );
}

void main() {
  test('MemberFamily.fromJson reads branch_year and role', () {
    final row = MemberFamily.fromJson({
      'id': 'a',
      'name': 'Ada',
      'created_at': '2020-01-01T00:00:00.000Z',
      'branch_year': 1987,
    }, role: 'co_owner');
    expect(row.branchYear, 1987);
    expect(row.role, 'co_owner');

    final missing = MemberFamily.fromJson({
      'id': 'b',
      'name': 'Bea',
      'created_at': '2020-01-01T00:00:00.000Z',
    });
    expect(missing.branchYear, isNull);
  });

  test('familySortKey trims, drops a leading The and ignores case', () {
    expect(familySortKey('  The Morgan Family '), 'morgan family');
    expect(familySortKey('Theodore'), 'theodore');
    expect(familySortKey('THE ash'), 'ash');
  });

  test('top level sorts A to Z by name key, then id', () {
    final rows = nestFamilies([
      _family('baker', 'The Baker'),
      _family('adams', 'adams'),
      _family('carter', 'Carter'),
    ]);
    expect(rows.map((row) => row.family.name).toList(), [
      'adams',
      'The Baker',
      'Carter',
    ]);
    expect(rows.every((row) => row.depth == 0), isTrue);

    final ties = nestFamilies([_family('b', 'Adams'), _family('a', 'Adams')]);
    expect(ties.map((row) => row.family.id).toList(), ['a', 'b']);
  });

  test('children sort by branch year, null last, then name key, then id', () {
    final rows = nestFamilies([
      _family('p', 'Parent'),
      _family('y1990', 'Later', parent: 'p', year: 1990),
      _family('none', 'Undated', parent: 'p'),
      _family('zed', 'Zed', parent: 'p', year: 1950),
      _family('amy', 'The Amy', parent: 'p', year: 1950),
      _family('b', 'Same', parent: 'p', year: 1970),
      _family('a', 'Same', parent: 'p', year: 1970),
    ]);
    expect(rows.map((row) => row.family.id).toList(), [
      'p',
      'amy',
      'zed',
      'a',
      'b',
      'y1990',
      'none',
    ]);
  });

  test('a child whose parent is not in the list is top level', () {
    final rows = nestFamilies([
      _family('baker', 'The Baker'),
      _family('orphan', 'adams', parent: 'missing'),
      _family('carter', 'Carter'),
    ]);
    expect(rows.map((row) => row.depth).toList(), [0, 0, 0]);
    expect(rows.map((row) => row.family.id).toList(), [
      'orphan',
      'baker',
      'carter',
    ]);
  });

  test('a child of a soft-deleted parent is top level', () {
    final rows = nestFamilies([
      _family('child', 'Bea', parent: 'deleted-parent'),
      _family('ada', 'Ada'),
    ]);
    expect(rows.map((row) => row.depth).toList(), [0, 0]);
    expect(rows.map((row) => row.family.id).toList(), ['ada', 'child']);
  });

  test('nesting reaches depth 3 and lists each family once', () {
    final input = [
      _family('d', 'Dee', parent: 'c'),
      _family('b', 'Bea', parent: 'a'),
      _family('a', 'Ada'),
      _family('c', 'Cee', parent: 'b'),
    ];
    final rows = nestFamilies(input);
    expect(rows.map((row) => row.family.id).toList(), ['a', 'b', 'c', 'd']);
    expect(rows.map((row) => row.depth).toList(), [0, 1, 2, 3]);
    expect(rows.length, input.length);
  });

  test('a parent cycle lists every family once', () {
    final rows = nestFamilies([
      _family('gamma', 'Gamma', parent: 'gamma'),
      _family('alpha', 'Alpha', parent: 'beta'),
      _family('beta', 'Beta', parent: 'alpha'),
    ]);
    expect(rows.map((row) => (row.family.name, row.depth)).toList(), [
      ('Gamma', 0),
      ('Alpha', 0),
      ('Beta', 1),
    ]);
    expect(rows.length, 3);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/family_selection.dart';

void main() {
  tearDown(FamilySelection.clear);

  test('remembered id in the membership set is returned', () {
    expect(
      resolveCurrentFamilyId(
        userId: 'user-a',
        remembered: 'fam-b',
        membershipIds: const ['fam-a', 'fam-b'],
        fallback: 'fam-a',
      ),
      'fam-b',
    );
  });

  test('a remembered id that is not a membership falls through', () {
    expect(
      resolveCurrentFamilyId(
        userId: 'user-a',
        remembered: 'gone',
        membershipIds: const ['fam-a'],
        fallback: 'fam-a',
      ),
      'fam-a',
    );
  });

  test('nothing remembered uses the fallback and no membership list', () {
    expect(
      resolveCurrentFamilyId(
        userId: 'user-a',
        remembered: null,
        fallback: 'fam-a',
      ),
      'fam-a',
    );
  });

  test('signed out returns null and ignores memberships and fallback', () {
    expect(
      resolveCurrentFamilyId(
        userId: null,
        remembered: 'fam-a',
        membershipIds: const ['fam-a'],
        fallback: 'fam-a',
      ),
      isNull,
    );
  });

  test('a different user clears the remembered family', () {
    FamilySelection.remember('fam-a');
    expect(FamilySelection.bindUser('user-a'), 'fam-a');

    expect(FamilySelection.bindUser('user-b'), isNull);
    expect(FamilySelection.id, isNull);
  });

  test('a dropped session clears the remembered family', () {
    FamilySelection.remember('fam-a');
    FamilySelection.bindUser('user-a');

    FamilySelection.clear();

    expect(FamilySelection.id, isNull);
    expect(FamilySelection.bindUser('user-a'), isNull);
  });
}

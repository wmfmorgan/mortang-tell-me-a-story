import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/features/family/delete_family_dialog.dart';
import 'package:tell_me_a_story/features/people/add_person_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('listed confirms use a blur shell and not AlertDialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () =>
                      showDeleteFamilyDialog(context, familyName: 'Ada'),
                  child: const Text('open-delete'),
                ),
                TextButton(
                  onPressed: () => AddPersonModal.show(
                    context,
                    familyId: 'fam',
                    api: _People(),
                  ),
                  child: const Text('open-person'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-person'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(const Key('add-person-picker')), findsOneWidget);
    expect(find.text('Create new person'), findsOneWidget);
    expect(find.text('+ Create new person'), findsNothing);
  });
}

class _People extends PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) {
    throw UnimplementedError();
  }
}

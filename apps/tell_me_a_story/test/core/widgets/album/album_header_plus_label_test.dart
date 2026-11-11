import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/data/families_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('new story header uses a plus circle and invite does not', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Ada',
            families: [
              MemberFamily(
                id: 'fam',
                name: 'Ada',
                createdAt: DateTime.utc(1980),
              ),
            ],
            currentFamilyId: 'fam',
            onFamilySelected: (_) {},
            onInvite: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+ New story'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'New story'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Invite'), findsNothing);
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    final invite = find.byKey(const Key('family-menu-invite'));
    expect(invite, findsOneWidget);
    expect(
      find.descendant(
        of: invite,
        matching: find.byIcon(Icons.person_add_outlined),
      ),
      findsOneWidget,
    );
  });
}

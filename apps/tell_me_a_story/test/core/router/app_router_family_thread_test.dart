import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

import '../../support/test_app_router.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('family-thread route builds FamilyThreadPage', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = testAppRouter(authRefresh: auth);
    addTearDown(auth.dispose);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.familyThread);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.familyThread);
    expect(find.byType(FamilyThreadPage), findsOneWidget);
    expect(find.byType(TimelinePage), findsNothing);
  });

  testWidgets('no widget links to /family-thread', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = testAppRouter(authRefresh: auth);
    addTearDown(auth.dispose);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();
    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();

    expect(_pathHits(tester, find.byType(TimelinePage)), isEmpty);
    expect(_pathHits(tester, find.byType(AlbumHeader)), isEmpty);
    expect(find.byType(FamilyThreadPage), findsNothing);
  });
}

List<String> _pathHits(WidgetTester tester, Finder root) {
  final hits = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    final text = widget is Text ? widget.data ?? '' : '';
    final label = widget is Semantics ? widget.properties.label ?? '' : '';
    final described = widget.toString();
    if (text.contains('/family-thread') ||
        label.contains('/family-thread') ||
        described.contains('/family-thread')) {
      hits.add('${widget.runtimeType}');
    }
    element.visitChildren(visit);
  }

  visit(tester.element(root));
  return hits;
}

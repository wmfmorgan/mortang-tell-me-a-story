import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
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

  test('no widget links to /family-thread', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run from apps/tell_me_a_story',
    );
    final hits = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = _libRelative(entity.path);
      if (relative == 'core/router/app_router.dart') continue;
      final source = entity.readAsStringSync();
      if (source.contains('AppRoutes.familyThread') ||
          source.contains('/family-thread')) {
        hits.add(relative);
      }
    }
    expect(hits, isEmpty);
  });
}

String _libRelative(String path) {
  final normalized = path.replaceAll('\\', '/');
  const marker = 'lib/';
  final index = normalized.lastIndexOf('/$marker');
  if (index >= 0) return normalized.substring(index + marker.length + 1);
  if (normalized.startsWith(marker)) {
    return normalized.substring(marker.length);
  }
  return normalized;
}

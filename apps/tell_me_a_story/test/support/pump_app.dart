import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/session/timeline_live.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

import 'fakes/fake_profile_repository.dart';
import 'fakes/fake_timeline_live.dart';

/// Overrides every widget test gets first: no live feed and a profile
/// repository whose `loadOwn` returns null. Later overrides win.
List<Override> get defaultTestOverrides => [
  timelineLiveProvider.overrideWithValue(FakeTimelineLive()),
  profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
];

/// [defaultTestOverrides] not replaced by [overrides], then [overrides]:
/// a container rejects two overrides of one provider.
List<Override> _withDefaults(List<Override> overrides) {
  final replaced = {for (final override in overrides) override.origin};
  return [
    for (final override in defaultTestOverrides)
      if (!replaced.contains(override.origin)) override,
    ...overrides,
  ];
}

/// Pumps [home] inside the app's theme, builder and forui localizations.
///
/// [size] sets the test view to that many logical pixels (ratio 1) and
/// resets it when the test ends.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
  ThemeData? theme,
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: _withDefaults(overrides),
      child: MaterialApp(
        theme: theme ?? albumTheme(),
        builder: albumAppBuilder,
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
}

/// Pumps [router] like the app does, with [defaultTestOverrides].
Future<void> pumpRouterApp(
  WidgetTester tester,
  GoRouter router, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _withDefaults(overrides),
      child: MaterialApp.router(
        theme: albumTheme(),
        builder: albumAppBuilder,
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

/// The [ProviderContainer] of the pumped app, to seed session state.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));

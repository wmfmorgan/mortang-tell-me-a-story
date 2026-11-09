import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

class TellMeAStoryApp extends StatelessWidget {
  const TellMeAStoryApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tell Me a Story',
      theme: albumTheme(),
      builder: albumAppBuilder,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}

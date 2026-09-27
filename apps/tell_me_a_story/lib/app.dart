import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/album_theme.dart';

class TellMeAStoryApp extends StatelessWidget {
  const TellMeAStoryApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tell Me a Story',
      theme: albumTheme(),
      routerConfig: router,
    );
  }
}

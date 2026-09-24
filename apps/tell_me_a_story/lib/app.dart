import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TellMeAStoryApp extends StatelessWidget {
  const TellMeAStoryApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tell Me a Story',
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';

/// Signed-in home stub. Full timeline UX is M6.
class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text('Timeline'),
        ),
      ),
    );
  }
}

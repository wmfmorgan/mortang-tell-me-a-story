import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// A container with [defaultTestOverrides] then [overrides], disposed when
/// the test ends. Tests read and seed session providers through it.
ProviderContainer albumTestContainer([List<Override> overrides = const []]) {
  final container = ProviderContainer(
    overrides: [...defaultTestOverrides, ...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps [app] over [container]. The app keeps its own `MaterialApp` so
/// these header tests render exactly as before.
Future<void> pumpScoped(
  WidgetTester tester,
  ProviderContainer container,
  Widget app,
) {
  return tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
}

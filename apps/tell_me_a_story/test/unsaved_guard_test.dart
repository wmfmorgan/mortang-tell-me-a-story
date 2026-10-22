import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('clean guard proceeds with no dialog', (tester) async {
    final guard = _guard(dirty: false);
    addTearDown(guard.dispose);
    final result = await _leave(tester, guard);
    expect(result, isTrue);
    expect(find.text('Leave this story?'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Stay, X, scrim tap and Esc return false', (tester) async {
    final guard = _guard();
    addTearDown(guard.dispose);

    Future<void> dismiss(Future<void> Function() tap) async {
      final pending = await _openPrompt(tester, guard);
      expect(find.text('Leave this story?'), findsOneWidget);
      await tap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await pending, isFalse);
    }

    await dismiss(() => tester.tap(find.text('Stay')));
    await dismiss(() => tester.tap(find.byIcon(Icons.close)));
    await dismiss(() => tester.tapAt(const Offset(12, 12)));
    await dismiss(() => tester.sendKeyEvent(LogicalKeyboardKey.escape));
    expect(find.text('Leave this story?'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Discard calls discard and returns true', (tester) async {
    var discarded = 0;
    final guard = _guard(onDiscard: () => discarded++);
    addTearDown(guard.dispose);
    final result = await _leave(
      tester,
      guard,
      act: () => tester.tap(find.text('Discard')),
    );
    expect(result, isTrue);
    expect(discarded, 1);
    expect(find.text('Leave this story?'), findsNothing);
  });

  testWidgets(
    'Save ok returns true; Save failure or false returns false and stays',
    (tester) async {
      final ok = _guard(onSave: () async => true);
      addTearDown(ok.dispose);
      expect(
        await _leave(tester, ok, act: () => tester.tap(find.text('Save'))),
        isTrue,
      );

      final denied = _guard(onSave: () async => false);
      addTearDown(denied.dispose);
      expect(
        await _leave(tester, denied, act: () => tester.tap(find.text('Save'))),
        isFalse,
      );
      expect(find.text('home'), findsOneWidget);
      expect(find.text('Leave this story?'), findsNothing);

      final failed = _guard(
        onSave: () async => throw StateError('save failed'),
      );
      addTearDown(failed.dispose);
      FlutterErrorDetails? reported;
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => reported = details;
      addTearDown(() => FlutterError.onError = previous);
      expect(
        await _leave(tester, failed, act: () => tester.tap(find.text('Save'))),
        isFalse,
      );
      expect(reported?.exception, isA<StateError>());
      expect(find.text('home'), findsOneWidget);
      expect(find.text('Leave this story?'), findsNothing);
    },
  );

  testWidgets('while saving all three buttons and the scrim are inert', (
    tester,
  ) async {
    final gate = Completer<bool>();
    var discarded = 0;
    final guard = _guard(
      onSave: () => gate.future,
      onDiscard: () => discarded++,
    );
    addTearDown(guard.dispose);
    final pending = await _openPrompt(tester, guard);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Stay'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Discard'),
          )
          .onPressed,
      isNull,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
    expect(
      save.style?.backgroundColor?.resolve({WidgetState.disabled}),
      albumTerracotta.withValues(alpha: 0.4),
    );

    await tester.tap(find.text('Stay'));
    await tester.tap(find.text('Discard'));
    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    expect(find.text('Leave this story?'), findsOneWidget);
    expect(discarded, 0);
    expect(gate.isCompleted, isFalse);

    gate.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await pending, isTrue);
  });

  testWidgets('a re-entrant confirmLeave returns false', (tester) async {
    final guard = _guard();
    addTearDown(guard.dispose);
    late Future<bool> first;
    late Future<bool> second;
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  first = guard.confirmLeave(context);
                  second = guard.confirmLeave(context);
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(await second, isFalse);
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(await first, isFalse);
  });
}

UnsavedGuard _guard({
  bool dirty = true,
  Future<bool> Function()? onSave,
  void Function()? onDiscard,
}) {
  return UnsavedGuard(
    exitPrompts: true,
    isDirty: () => dirty,
    save: onSave ?? () async => true,
    discard: onDiscard ?? () {},
  );
}

Future<bool> _leave(
  WidgetTester tester,
  UnsavedGuard guard, {
  Future<void> Function()? act,
}) async {
  final pending = await _openPrompt(tester, guard);
  if (act != null) {
    await act();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return pending;
}

/// The dialog future, without waiting for the user to answer it.
Future<Future<bool>> _openPrompt(
  WidgetTester tester,
  UnsavedGuard guard,
) async {
  final opened = Completer<Future<bool>>();
  await tester.pumpWidget(
    MaterialApp(
      theme: albumTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Column(
              children: [
                const Text('home'),
                TextButton(
                  onPressed: () {
                    opened.complete(guard.confirmLeave(context));
                  },
                  child: const Text('go'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return opened.future;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/comments/comment_composer.dart';

Finder _field() => find.byType(TextField);
Finder _post() => find.widgetWithText(FilledButton, 'Post');

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function(String body) onPost,
  FocusNode? focusNode,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CommentComposer(onPost: onPost, focusNode: focusNode),
      ),
    ),
  );
}

void main() {
  testWidgets('shows placeholder and Post', (tester) async {
    await _pump(tester, onPost: (_) async {});

    expect(find.text('Share a short memory or note...'), findsOneWidget);
    expect(_post(), findsOneWidget);
  });

  testWidgets('empty Post is a no-op', (tester) async {
    var calls = 0;
    await _pump(tester, onPost: (_) async => calls++);

    await tester.tap(_post());
    await tester.pump();

    expect(calls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('whitespace Post is a no-op', (tester) async {
    var calls = 0;
    await _pump(tester, onPost: (_) async => calls++);

    await tester.enterText(_field(), '  \n\t');
    await tester.tap(_post());
    await tester.pump();

    expect(calls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Post with text calls onPost and clears the field', (
    tester,
  ) async {
    final posted = <String>[];
    await _pump(tester, onPost: (body) async => posted.add(body));

    await tester.enterText(_field(), '  I remember the pie.  ');
    await tester.tap(_post());
    await tester.pumpAndSettle();

    expect(posted, ['I remember the pie.']);
    expect(tester.widget<TextField>(_field()).controller?.text, isEmpty);
  });

  testWidgets('failed Post keeps the field', (tester) async {
    await _pump(tester, onPost: (_) async => throw StateError('create failed'));

    await tester.enterText(_field(), 'Keep me');
    await tester.tap(_post());
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_field()).controller?.text, 'Keep me');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';
import 'package:tell_me_a_story/features/perspectives/add_perspective_page.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';
const _storyId = 's1';

class _FakePerspectivesApi implements PerspectivesGateway {
  _FakePerspectivesApi({this.throwOnCreate = false});

  final bool throwOnCreate;
  var createCalls = 0;
  String? lastStoryId;
  String? lastFamilyId;
  String? lastBody;

  @override
  Future<List<Perspective>> listForStory(String storyId) async => const [];

  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    createCalls++;
    lastStoryId = storyId;
    lastFamilyId = familyId;
    lastBody = body;
    if (throwOnCreate) throw StateError('create failed');
    ensureValidPerspectiveBody(body);
    return Perspective(
      id: 'v-new',
      storyId: storyId,
      familyId: familyId,
      authorId: 'u1',
      body: body.trim(),
      createdAt: DateTime.utc(2026, 9, 27),
      authorDisplayName: 'Me',
    );
  }

  @override
  Future<void> update({required String id, required String body}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}
}

Finder _publish() => find.widgetWithText(FilledButton, 'Publish perspective');
Finder _cancel() => find.widgetWithText(OutlinedButton, 'Cancel');
Finder _bodyField() => find.byKey(const Key('perspective-body'));

Future<GoRouter> _pumpOverlay(
  WidgetTester tester, {
  required PerspectivesGateway api,
  String familyId = _familyId,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.storyPath(_storyId),
    routes: [
      GoRoute(
        path: AppRoutes.story,
        builder: (context, state) => const Scaffold(body: Text('reader-dest')),
      ),
      GoRoute(
        path: AppRoutes.storyPerspective,
        builder: (context, state) => AddPerspectivePage(
          storyId: state.pathParameters['storyId']!,
          familyId: familyId,
          perspectivesApi: api,
        ),
      ),
    ],
  );
  await tester.pumpWidget(TellMeAStoryApp(router: router));
  await tester.pumpAndSettle();
  router.push(AppRoutes.storyPerspectivePath(_storyId));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('posting as shows the name and Author when ids match', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.storyPerspectivePath(_storyId),
      routes: [
        GoRoute(
          path: AppRoutes.storyPerspective,
          builder: (context, state) => AddPerspectivePage(
            storyId: state.pathParameters['storyId']!,
            familyId: _familyId,
            perspectivesApi: _FakePerspectivesApi(),
            postingAs: 'Dad (Thomas)',
            storyAuthorId: 'u1',
            currentUserId: 'u1',
          ),
        ),
      ],
    );
    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Posting as'), findsOneWidget);
    expect(find.text('Dad (Thomas)'), findsOneWidget);
    expect(find.text('DT'), findsOneWidget);
    expect(find.text('Author'), findsOneWidget);
  });

  testWidgets('shows locked Add Perspective copy and no title field', (
    tester,
  ) async {
    await _pumpOverlay(tester, api: _FakePerspectivesApi());

    expect(find.byKey(const Key('add-perspective')), findsOneWidget);
    expect(find.text('FAMILY PERSPECTIVE'), findsOneWidget);
    expect(find.text('Add your perspective'), findsOneWidget);
    expect(
      find.text(
        'Tell this story in your own words — a full telling, not a quick reaction.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your story'), findsOneWidget);
    expect(find.text('0 words'), findsOneWidget);
    expect(
      find.text('What do you remember? Who was there, what was said…'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Only you can edit this perspective later. Use Comments below for short reactions.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Close modal'), findsOneWidget);
    expect(_publish(), findsOneWidget);
    expect(_cancel(), findsOneWidget);
    expect(find.text('Perspective title'), findsNothing);
    expect(find.textContaining('title (optional)'), findsNothing);
    expect(find.text('Posting as'), findsNothing);
  });

  testWidgets('Cancel pops the overlay', (tester) async {
    await _pumpOverlay(tester, api: _FakePerspectivesApi());

    await tester.ensureVisible(_cancel());
    await tester.tap(_cancel());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-perspective')), findsNothing);
    expect(find.text('reader-dest'), findsOneWidget);
  });

  testWidgets('empty and whitespace disable Publish and keep the overlay', (
    tester,
  ) async {
    final api = _FakePerspectivesApi();
    await _pumpOverlay(tester, api: api);

    expect(tester.widget<FilledButton>(_publish()).onPressed, isNull);

    await tester.enterText(_bodyField(), '  \n\t');
    await tester.pump();

    expect(tester.widget<FilledButton>(_publish()).onPressed, isNull);
    expect(find.byKey(const Key('add-perspective')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.ensureVisible(_publish());
    await tester.tap(_publish());
    await tester.pump();

    expect(api.createCalls, 0);
    expect(find.byKey(const Key('add-perspective')), findsOneWidget);
  });

  testWidgets('Publish with text calls create then pops', (tester) async {
    final api = _FakePerspectivesApi();
    await _pumpOverlay(tester, api: api);

    await tester.enterText(
      _bodyField(),
      '  From the porch it looked different.  ',
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(_publish()).onPressed, isNotNull);
    expect(find.text('6 words'), findsOneWidget);

    await tester.ensureVisible(_publish());
    await tester.tap(_publish());
    await tester.pumpAndSettle();

    expect(api.createCalls, 1);
    expect(api.lastStoryId, _storyId);
    expect(api.lastFamilyId, _familyId);
    expect(api.lastBody, 'From the porch it looked different.');
    expect(find.byKey(const Key('add-perspective')), findsNothing);
    expect(find.text('reader-dest'), findsOneWidget);
  });

  testWidgets('failed Publish shows Try again and stays on the overlay', (
    tester,
  ) async {
    final api = _FakePerspectivesApi(throwOnCreate: true);
    await _pumpOverlay(tester, api: api);

    await tester.enterText(_bodyField(), 'Keep me');
    await tester.pump();
    await tester.ensureVisible(_publish());
    await tester.tap(_publish());
    await tester.pumpAndSettle();

    expect(api.createCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('add-perspective')), findsOneWidget);
    expect(tester.widget<TextField>(_bodyField()).controller?.text, 'Keep me');
  });
}

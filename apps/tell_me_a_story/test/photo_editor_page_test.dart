import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/photo/photo_editing_storage.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/features/photo_editing/photo_editor_page.dart';

class _Gateway implements PhotoEditingGateway {
  _Gateway(this.photo);

  Photo photo;
  Object? error;
  final uploads = <String>[];
  int reads = 0;

  @override
  Future<Uint8List> download(String path) async => _jpeg();

  @override
  Future<Photo> readPhoto(String photoId) async {
    reads += 1;
    return photo;
  }

  @override
  Future<void> remove(List<String> paths) async {}

  @override
  Future<PhotoEditResult> resetPhotoEdit({
    required String photoId,
    required int expectedVersion,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    final previous = photo.editedStoragePath;
    photo = photo.copyWith(
      editedStoragePath: null,
      editVersion: expectedVersion + 1,
    );
    return PhotoEditResult(
      editVersion: photo.editVersion,
      previousPath: previous,
    );
  }

  @override
  Future<PhotoEditResult> savePhotoEdit({
    required String photoId,
    required int expectedVersion,
    required String editedPath,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    photo = photo.copyWith(
      editedStoragePath: editedPath,
      editVersion: expectedVersion + 1,
    );
    return PhotoEditResult(editVersion: photo.editVersion, previousPath: null);
  }

  @override
  Future<void> uploadJpeg({
    required String path,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    uploads.add(path);
  }
}

Photo _photo({String? edited}) {
  return Photo(
    id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    storyId: '11111111-1111-1111-1111-111111111111',
    familyId: '22222222-2222-2222-2222-222222222222',
    uploaderId: 'user',
    storagePath: 'orig.jpg',
    editedStoragePath: edited,
    editVersion: edited == null ? 0 : 2,
    sortOrder: 0,
  );
}

Uint8List _jpeg() {
  final image = img.Image(width: 16, height: 8);
  img.fill(image, color: img.ColorRgb8(80, 40, 20));
  return Uint8List.fromList(img.encodeJpg(image));
}

Future<Photo?> _pump(
  WidgetTester tester, {
  required _Gateway gateway,
  Photo? photo,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Photo? popped;
  await tester.pumpWidget(
    MaterialApp(
      theme: albumTheme(),
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Photo>(
                MaterialPageRoute(
                  builder: (context) => PhotoEditorPage(
                    photo: photo ?? _photo(),
                    bytes: _jpeg(),
                    editing: PhotoEditingApi(gateway),
                  ),
                ),
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return popped;
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'tools are crop rotate text and adjust, with Literata and no stickers',
    (tester) async {
      final gateway = _Gateway(_photo());
      await _pump(tester, gateway: gateway);
      expect(find.text(photoToolCrop), findsOneWidget);
      expect(find.text(photoToolRotate), findsOneWidget);
      expect(find.text(photoToolText), findsOneWidget);
      expect(find.text(photoToolAdjust), findsOneWidget);
      expect(find.text('Stickers'), findsNothing);
      await tester.tap(find.text(photoToolText));
      await tester.pump();
      await tester.tap(find.text(photoAddText));
      await tester.pump();
      expect(find.text('Literata'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Literata')).style?.fontFamily,
        contains('Literata'),
      );
      expect(find.text(photoEditorTitle), findsOneWidget);
    },
  );

  testWidgets('dirty cancel keeps editing by default and discard closes', (
    tester,
  ) async {
    final gateway = _Gateway(_photo());
    await _pump(tester, gateway: gateway);
    await tester.tap(find.text(photoToolRotate));
    await tester.pump();
    await tester.tap(find.text(photoRotateRight));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editor-cancel')));
    await tester.pumpAndSettle();
    expect(find.text(photoDiscardTitle), findsOneWidget);
    expect(find.text(photoDiscardBody), findsOneWidget);
    final keep = tester.widget<TextButton>(
      find.widgetWithText(TextButton, photoKeepEditing),
    );
    expect(keep.autofocus, isTrue);
    await tester.tap(find.text(photoKeepEditing));
    await tester.pumpAndSettle();
    expect(find.text(photoRotateRight), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(photoDiscardEdits));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('conflict keeps the edit and retry reads the latest version', (
    tester,
  ) async {
    final gateway = _Gateway(_photo());
    gateway.error = Exception('CONFLICT: photo edit version');
    await _pump(tester, gateway: gateway);
    await tester.tap(find.text(photoToolRotate));
    await tester.pump();
    await tester.tap(find.text(photoRotateRight));
    await tester.pump();
    await tester.tap(find.text(photoSave));
    await tester.pumpAndSettle();
    expect(find.text(photoConflictTitle), findsOneWidget);
    expect(find.text(photoConflictBody), findsOneWidget);
    expect(find.text(photoTrySaveAgain), findsOneWidget);
    expect(find.text(photoLoadLatest), findsOneWidget);
    expect(find.text(photoKeepEditing), findsWidgets);
    await tester.tap(find.text(photoKeepEditing).last);
    await tester.pumpAndSettle();
    expect(find.text(photoRotateRight), findsOneWidget);
    gateway.photo = _photo().copyWith(editedStoragePath: null, editVersion: 4);
    await tester.tap(find.text(photoSave));
    await tester.pumpAndSettle();
    expect(find.text(photoTrySaveAgain), findsOneWidget);
    gateway.error = null;
    await tester.tap(find.text(photoTrySaveAgain));
    await tester.pumpAndSettle();
    expect(gateway.reads, greaterThan(0));
    expect(gateway.uploads.last, endsWith('.edited.5.jpg'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/photo_editing/photo_edit_model.dart';

void main() {
  PhotoEditModel open() {
    return PhotoEditModel.open(
      imageWidth: 400,
      imageHeight: 200,
      editVersion: 3,
    );
  }

  test('crop stays inside the image after a right-angle rotation', () {
    final model = open().setAspect(CropAspect.square).rotateRight();
    final crop = model.document.crop;
    expect(crop.left, greaterThanOrEqualTo(0));
    expect(crop.top, greaterThanOrEqualTo(0));
    expect(crop.left + crop.width, lessThanOrEqualTo(1));
    expect(crop.top + crop.height, lessThanOrEqualTo(1));
    expect(model.document.quarterTurns, 1);
    final bounds = model.rotatedCropBounds();
    expect(bounds, hasLength(4));
    for (final rect in bounds) {
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    }
  });

  test('re-center restores the largest centered crop for the aspect', () {
    final shifted = open()
        .setAspect(CropAspect.square)
        .setCrop(const CropQuad(left: 0.4, top: 0.1, width: 0.2, height: 0.2));
    final recentered = shifted.recenterCrop();
    expect(recentered.document.crop.left, closeTo(0.25, 0.001));
    expect(recentered.document.crop.top, closeTo(0, 0.001));
  });

  test('brightness changes the pixel epoch and selection does not', () {
    final model = open();
    final bright = model.setBrightness(20);
    expect(bright.pixelsEpoch, greaterThan(model.pixelsEpoch));
    expect(bright.document.brightness, 20);
    expect(bright.document.contrast, 0);
    final added = bright.addText();
    final selected = added.select('t1');
    expect(selected.pixelsEpoch, added.pixelsEpoch);
  });

  test('a gesture is one undo step and a later edit clears redo', () {
    final model = open().beginGesture();
    final moved = model.previewDocument(
      model.document.copyWith(brightness: 10),
    );
    final again = moved.previewDocument(
      moved.document.copyWith(brightness: 40),
    );
    final committed = again.endGesture();
    expect(committed.undoStack, hasLength(1));
    expect(committed.document.brightness, 40);
    final undone = committed.undo();
    expect(undone.document.brightness, 0);
    expect(undone.canRedo, isTrue);
    final edited = undone.setContrast(5);
    expect(edited.canRedo, isFalse);
  });

  test('reset edits returns to the opening document in one undo step', () {
    final edited = open().rotateLeft().setBrightness(15);
    final reset = edited.resetEdits();
    expect(reset.document.quarterTurns, 0);
    expect(reset.document.brightness, 0);
    expect(reset.canUndo, isTrue);
    expect(reset.undo().document.brightness, 15);
  });

  test('text size stays inside 16 to 96 and starts at 32', () {
    final added = open().addText();
    expect(added.selected?.fontSize, 32);
    final huge = added.setSelectedSize(200);
    expect(huge.selected?.fontSize, 96);
    final tiny = huge.setSelectedSize(4);
    expect(tiny.selected?.fontSize, 16);
  });
}

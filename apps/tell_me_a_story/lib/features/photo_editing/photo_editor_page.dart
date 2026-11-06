import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import '../../core/navigation/unsaved_guard.dart';
import '../../core/photo/photo_editing_storage.dart';
import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import 'photo_edit_model.dart';
import 'photo_edit_renderer.dart';

const photoEditorTitle = 'Edit photo';
const photoEditAttachLabel = 'Edit photo';
const photoEditExistingLabel = 'Edit';
const photoToolCrop = 'Crop';
const photoToolRotate = 'Rotate';
const photoToolText = 'Text';
const photoToolAdjust = 'Adjust';
const photoCropFree = 'Free';
const photoCropOriginal = 'Original';
const photoCropSquare = '1:1';
const photoCropFourThree = '4:3';
const photoCropThreeFour = '3:4';
const photoCropWide = '16:9';
const photoRecenter = 'Re-center crop';
const photoRotateLeft = 'Rotate left 90°';
const photoRotateRight = 'Rotate right 90°';
const photoAddText = 'Add text';
const photoDeleteText = 'Delete text';
const photoFontLabel = 'Font';
const photoSizeLabel = 'Size';
const photoColorLabel = 'Color';
const photoBrightness = 'Brightness';
const photoContrast = 'Contrast';
const photoResetBrightness = 'Reset brightness';
const photoResetContrast = 'Reset contrast';
const photoCancel = 'Cancel';
const photoSave = 'Save';
const photoUndo = 'Undo';
const photoRedo = 'Redo';
const photoResetEdits = 'Reset edits';
const photoResetOriginal = 'Reset to original';
const photoDiscardTitle = 'Discard edits?';
const photoDiscardBody = 'Your changes to this photo won’t be saved.';
const photoKeepEditing = 'Keep editing';
const photoDiscardEdits = 'Discard edits';
const photoPreparing = 'Preparing photo…';
const photoSaving = 'Saving photo…';
const photoLoadError = 'Couldn’t open this photo.';
const photoRetry = 'Retry';
const photoBack = 'Back';
const photoSaveError = 'Couldn’t save your edits. Try again.';
const photoResetTitle = 'Reset to original?';
const photoResetBody =
    'This removes the edits everywhere this photo appears. Your original photo will be restored.';
const photoKeepEdits = 'Keep edits';
const photoResetAction = 'Reset';
const photoResetError = 'Couldn’t restore the original. Try again.';
const photoZoomIn = 'Zoom in';
const photoZoomOut = 'Zoom out';
const photoConflictTitle = 'This photo changed in another session.';
const photoConflictBody =
    'Your work is still here. Try again, or load the latest photo and let your unsaved edits go.';
const photoTrySaveAgain = 'Try save again';
const photoTryResetAgain = 'Try reset again';
const photoLoadLatest = 'Load latest';
const photoReloadTitle = 'Load latest photo?';
const photoReloadBody =
    'Your unsaved edits will be replaced. Your latest saved photo will be loaded.';

const photoSwatchNames = <TextSwatch, String>{
  TextSwatch.parchment: 'Parchment',
  TextSwatch.ink: 'Ink',
  TextSwatch.terracotta: 'Terracotta',
  TextSwatch.sage: 'Sage',
  TextSwatch.branchMoss: 'Branch moss',
};

/// Arguments the route receives. The route does not read the database itself.
class PhotoEditorArgs {
  const PhotoEditorArgs({
    required this.photo,
    required this.bytes,
    required this.editing,
  });

  final Photo photo;
  final Uint8List bytes;
  final PhotoEditingApi editing;
}

enum _EditorTool { crop, rotate, text, adjust }

enum _EditorPhase { preparing, ready, loadError, saving }

/// Editor for one photo. Save and reset go through [PhotoEditingApi].
class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({
    super.key,
    this.photo,
    this.bytes,
    this.editing,
    this.pageKey,
  });

  final Photo? photo;
  final Uint8List? bytes;
  final PhotoEditingApi? editing;
  final ValueKey<String>? pageKey;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  final _renderer = const PhotoEditRenderer();
  final _saveFocus = FocusNode();
  final _resetFocus = FocusNode();
  UnsavedGuard? _guard;

  _EditorPhase _phase = _EditorPhase.preparing;
  _EditorTool _tool = _EditorTool.crop;
  PhotoEditModel? _model;
  Uint8List? _bytes;
  Photo? _photo;
  int _expected = 0;
  double _zoom = 1;
  String? _banner;
  bool _bannerIsReset = false;
  bool _conflictFromReset = false;

  bool get _dirty => _model?.isDirty ?? false;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    _bytes = widget.bytes;
    _expected = widget.photo?.editVersion ?? 0;
    _guard = UnsavedGuard(
      exitPrompts: true,
      isDirty: () => _dirty,
      save: () async => false,
      discard: () {},
    );
    final key = widget.pageKey;
    if (key != null) UnsavedGuards.register(key, _guard!);
    _prepare(widget.bytes);
  }

  @override
  void dispose() {
    final key = widget.pageKey;
    final guard = _guard;
    if (key != null && guard != null) UnsavedGuards.unregister(key, guard);
    _saveFocus.dispose();
    _resetFocus.dispose();
    super.dispose();
  }

  Future<void> _prepare(Uint8List? bytes) async {
    if (bytes == null ||
        bytes.isEmpty ||
        widget.editing == null ||
        _photo == null) {
      setState(() => _phase = _EditorPhase.loadError);
      return;
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      setState(() => _phase = _EditorPhase.loadError);
      return;
    }
    setState(() {
      _bytes = bytes;
      _model = PhotoEditModel.open(
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        editVersion: _expected,
      );
      _phase = _EditorPhase.ready;
      _banner = null;
    });
    _guard?.changed();
  }

  void _previewText(PhotoEditModel model, String value) {
    final selected = model.selected;
    if (selected == null) return;
    final layers = [
      for (final layer in model.document.layers)
        if (layer.id == selected.id) layer.copyWith(text: value) else layer,
    ];
    final started = model.beginGesture();
    _setModel(
      started.previewDocument(started.document.copyWith(layers: layers)),
    );
  }

  void _setModel(PhotoEditModel model) {
    setState(() => _model = model);
    _guard?.changed();
  }

  Future<void> _close() async {
    if (_phase == _EditorPhase.saving) return;
    if (!_dirty) {
      _leave(null);
      return;
    }
    final discard = await _choiceDialog(
      title: photoDiscardTitle,
      body: photoDiscardBody,
      actions: const [photoKeepEditing, photoDiscardEdits],
      primary: photoKeepEditing,
    );
    if (discard == photoDiscardEdits && mounted) _leave(null);
  }

  void _leave(Photo? photo) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop(photo);
      return;
    }
    Navigator.of(context).pop(photo);
  }

  Future<void> _save() async {
    final model = _model;
    final photo = _photo;
    final editing = widget.editing;
    final bytes = _bytes;
    if (model == null || photo == null || editing == null || bytes == null) {
      return;
    }
    if (!model.isDirty || _phase == _EditorPhase.saving) return;
    setState(() {
      _phase = _EditorPhase.saving;
      _banner = null;
    });
    try {
      final jpeg = await _renderer.bakeJpeg(
        source: bytes,
        document: model.document,
      );
      final path = await editing.uploadCandidate(photo, jpeg, _expected + 1);
      final result = await editing.savePhotoEdit(photo.id, _expected, path);
      if (!mounted) return;
      _leave(
        photo.copyWith(
          editedStoragePath: path,
          editVersion: result.editVersion,
        ),
      );
    } on PhotoEditException catch (error) {
      if (!mounted) return;
      setState(() => _phase = _EditorPhase.ready);
      if (error.kind == PhotoEditFailureKind.conflict) {
        _conflictFromReset = false;
        await _showConflict();
      } else {
        setState(() {
          _banner = photoSaveError;
          _bannerIsReset = false;
        });
        _saveFocus.requestFocus();
      }
    }
  }

  Future<void> _resetOriginal() async {
    final photo = _photo;
    if (photo == null || photo.editedStoragePath == null) return;
    final go = await _choiceDialog(
      title: photoResetTitle,
      body: photoResetBody,
      actions: const [photoKeepEdits, photoResetAction],
      primary: photoKeepEdits,
    );
    if (go != photoResetAction || !mounted) return;
    await _runReset();
  }

  Future<void> _runReset() async {
    final photo = _photo;
    final editing = widget.editing;
    if (photo == null || editing == null) return;
    setState(() {
      _phase = _EditorPhase.saving;
      _banner = null;
    });
    try {
      final result = await editing.resetPhotoEdit(photo.id, _expected);
      if (!mounted) return;
      _leave(
        photo.copyWith(
          editedStoragePath: null,
          editVersion: result.editVersion,
        ),
      );
    } on PhotoEditException catch (error) {
      if (!mounted) return;
      setState(() => _phase = _EditorPhase.ready);
      if (error.kind == PhotoEditFailureKind.conflict) {
        _conflictFromReset = true;
        await _showConflict();
      } else {
        setState(() {
          _banner = photoResetError;
          _bannerIsReset = true;
        });
        _resetFocus.requestFocus();
      }
    }
  }

  Future<void> _showConflict() async {
    final retry = _conflictFromReset ? photoTryResetAgain : photoTrySaveAgain;
    final choice = await _choiceDialog(
      title: photoConflictTitle,
      body: photoConflictBody,
      actions: [retry, photoLoadLatest, photoKeepEditing],
      primary: photoKeepEditing,
    );
    if (!mounted || choice == null || choice == photoKeepEditing) {
      if (mounted) {
        (_conflictFromReset ? _resetFocus : _saveFocus).requestFocus();
      }
      return;
    }
    if (choice == photoLoadLatest) {
      await _loadLatest();
      return;
    }
    await _retrySameOperation();
  }

  Future<void> _retrySameOperation() async {
    final editing = widget.editing;
    final photo = _photo;
    if (editing == null || photo == null) return;
    setState(() => _phase = _EditorPhase.saving);
    try {
      final latest = await editing.readPhoto(photo.id);
      if (!mounted) return;
      _expected = latest.editVersion;
      _photo = latest;
      setState(() => _phase = _EditorPhase.ready);
      if (_conflictFromReset) {
        await _runReset();
      } else {
        await _save();
      }
    } on PhotoEditException {
      if (!mounted) return;
      setState(() {
        _phase = _EditorPhase.ready;
        _banner = _conflictFromReset ? photoResetError : photoSaveError;
        _bannerIsReset = _conflictFromReset;
      });
    }
  }

  Future<void> _loadLatest() async {
    if (_dirty) {
      final choice = await _choiceDialog(
        title: photoReloadTitle,
        body: photoReloadBody,
        actions: const [photoKeepEditing, photoLoadLatest],
        primary: photoKeepEditing,
      );
      if (choice != photoLoadLatest || !mounted) return;
    }
    final editing = widget.editing;
    final photo = _photo;
    if (editing == null || photo == null) return;
    setState(() => _phase = _EditorPhase.preparing);
    try {
      final latest = await editing.readPhoto(photo.id);
      final bytes = await editing.download(latest.effectiveStoragePath);
      if (!mounted) return;
      _photo = latest;
      _expected = latest.editVersion;
      await _prepare(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _EditorPhase.ready;
        _banner = photoLoadError;
        _bannerIsReset = false;
      });
    }
  }

  Future<String?> _choiceDialog({
    required String title,
    required String body,
    required List<String> actions,
    required String primary,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: albumParchment,
          surfaceTintColor: albumParchment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: albumModalBorder),
          ),
          title: Text(title, style: GoogleFonts.literata(color: albumInk)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(body, style: GoogleFonts.literata(color: albumInk)),
          ),
          actions: [
            for (final action in actions)
              TextButton(
                autofocus: action == primary,
                onPressed: () => Navigator.of(context).pop(action),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor:
                      action == photoLoadLatest ||
                          action == photoDiscardEdits ||
                          action == photoResetAction
                      ? albumTerracotta
                      : albumInk,
                ),
                child: Text(action),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return PopScope(
      canPop: !_dirty && _phase != _EditorPhase.saving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: RepaintBoundary(
        key: const Key('photo-editor-shot'),
        child: Material(
          key: const Key('photo-editor'),
          color: albumParchment,
          child: wide ? _wide() : _phone(),
        ),
      ),
    );
  }

  Widget _phone() {
    return Column(
      children: [
        _header(),
        Expanded(child: _canvas()),
        _sheet(),
      ],
    );
  }

  Widget _wide() {
    return Column(
      children: [
        _header(),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _canvas()),
              SizedBox(width: 360, child: _sheet(rail: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final model = _model;
    final edited = _photo?.editedStoragePath != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('editor-cancel'),
            tooltip: photoCancel,
            onPressed: _phase == _EditorPhase.saving ? null : _close,
            icon: const Icon(Icons.close, color: albumInk),
          ),
          Flexible(
            child: Text(
              photoEditorTitle,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.literata(color: albumInk, fontSize: 20),
            ),
          ),
          if (edited)
            TextButton(
              focusNode: _resetFocus,
              onPressed: _phase == _EditorPhase.ready ? _resetOriginal : null,
              child: const Text(photoResetOriginal),
            ),
          const Spacer(),
          IconButton(
            tooltip: photoUndo,
            onPressed:
                model != null && model.canUndo && _phase == _EditorPhase.ready
                ? () => _setModel(model.undo())
                : null,
            icon: const Icon(Icons.undo, color: albumInk),
          ),
          IconButton(
            tooltip: photoRedo,
            onPressed:
                model != null && model.canRedo && _phase == _EditorPhase.ready
                ? () => _setModel(model.redo())
                : null,
            icon: const Icon(Icons.redo, color: albumInk),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    if (_phase == _EditorPhase.preparing) {
      return const Center(child: Text(photoPreparing));
    }
    if (_phase == _EditorPhase.loadError || _bytes == null) {
      return _loadFailure();
    }
    final bytes = _bytes!;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: albumParchment.withValues(alpha: 0.88),
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: false,
              child: Transform.scale(
                scale: _zoom,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Row(
            children: [
              _zoomButton(photoZoomOut, Icons.remove, () {
                setState(() => _zoom = (_zoom / 1.25).clamp(1, 4));
              }),
              _zoomButton(photoZoomIn, Icons.add, () {
                setState(() => _zoom = (_zoom * 1.25).clamp(1, 4));
              }),
            ],
          ),
        ),
        if (_phase == _EditorPhase.saving)
          const Positioned.fill(
            child: ColoredBox(
              color: albumModalScrim,
              child: Center(child: Text(photoSaving)),
            ),
          ),
      ],
    );
  }

  Widget _zoomButton(String label, IconData icon, VoidCallback onPressed) {
    return IconButton(
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: _phase == _EditorPhase.ready ? onPressed : null,
      icon: Icon(icon, color: albumInk),
    );
  }

  Widget _loadFailure() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(photoLoadError, style: GoogleFonts.literata(color: albumInk)),
          TextButton(
            onPressed: () => _prepare(_bytes ?? widget.bytes),
            child: const Text(photoRetry),
          ),
          TextButton(
            onPressed: () => _leave(null),
            child: const Text(photoBack),
          ),
        ],
      ),
    );
  }

  Widget _sheet({bool rail = false}) {
    final toolsEnabled = _phase == _EditorPhase.ready;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: albumParchment,
        borderRadius: rail
            ? null
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: albumModalBorder),
      ),
      child: Column(
        mainAxisSize: rail ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (!rail)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: albumSage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (_banner != null) _bannerRow(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _toolBody(toolsEnabled),
          ),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _toolButton(_EditorTool.crop, photoToolCrop, Icons.crop),
                _toolButton(
                  _EditorTool.rotate,
                  photoToolRotate,
                  Icons.rotate_right,
                ),
                _toolButton(_EditorTool.text, photoToolText, Icons.title),
                _toolButton(_EditorTool.adjust, photoToolAdjust, Icons.tune),
              ],
            ),
          ),
          _actions(toolsEnabled),
        ],
      ),
    );
  }

  Widget _bannerRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_banner!, style: GoogleFonts.literata(color: albumInk)),
          TextButton(
            onPressed: _bannerIsReset ? _runReset : _save,
            child: const Text(photoRetry),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(_EditorTool tool, String label, IconData icon) {
    final selected = _tool == tool;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: _phase == _EditorPhase.ready
            ? () {
                final model = _model;
                setState(() {
                  if (model != null) _model = model.endGesture();
                  _tool = tool;
                });
                _guard?.changed();
              }
            : null,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? albumTerracotta : albumParchment,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? albumTerracotta : albumSage,
                  width: selected ? 3 : 1,
                ),
              ),
              child: Icon(icon, color: selected ? albumParchment : albumInk),
            ),
            Text(
              label,
              style: GoogleFonts.literata(color: albumInk, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBody(bool enabled) {
    final model = _model;
    if (model == null) return const SizedBox(height: 48);
    return switch (_tool) {
      _EditorTool.crop => _cropBody(model, enabled),
      _EditorTool.rotate => _rotateBody(model, enabled),
      _EditorTool.text => _textBody(model, enabled),
      _EditorTool.adjust => _adjustBody(model, enabled),
    };
  }

  Widget _cropBody(PhotoEditModel model, bool enabled) {
    const presets = <CropAspect, String>{
      CropAspect.free: photoCropFree,
      CropAspect.original: photoCropOriginal,
      CropAspect.square: photoCropSquare,
      CropAspect.fourThree: photoCropFourThree,
      CropAspect.threeFour: photoCropThreeFour,
      CropAspect.widescreen: photoCropWide,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final entry in presets.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: model.document.aspect == entry.key,
                onSelected: enabled
                    ? (_) => _setModel(model.setAspect(entry.key))
                    : null,
              ),
          ],
        ),
        TextButton(
          onPressed: enabled ? () => _setModel(model.recenterCrop()) : null,
          child: const Text(photoRecenter),
        ),
        Wrap(
          spacing: 8,
          children: [
            _nudge('Crop left', enabled, () {
              final crop = model.document.crop;
              _setModel(
                model.setCrop(
                  CropQuad(
                    left: crop.left - 0.05,
                    top: crop.top,
                    width: crop.width,
                    height: crop.height,
                  ),
                ),
              );
            }),
            _nudge('Crop right', enabled, () {
              final crop = model.document.crop;
              _setModel(
                model.setCrop(
                  CropQuad(
                    left: crop.left + 0.05,
                    top: crop.top,
                    width: crop.width,
                    height: crop.height,
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _rotateBody(PhotoEditModel model, bool enabled) {
    return Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: enabled ? () => _setModel(model.rotateLeft()) : null,
          child: const Text(photoRotateLeft),
        ),
        TextButton(
          onPressed: enabled ? () => _setModel(model.rotateRight()) : null,
          child: const Text(photoRotateRight),
        ),
      ],
    );
  }

  Widget _textBody(PhotoEditModel model, bool enabled) {
    final selected = model.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: enabled ? () => _setModel(model.addText()) : null,
          child: const Text(photoAddText),
        ),
        Text(photoFontLabel, style: GoogleFonts.literata(color: albumInk)),
        Text('Literata', style: GoogleFonts.literata(color: albumSage)),
        if (selected != null) ...[
          TextFormField(
            key: Key('text-layer-${selected.id}'),
            enabled: enabled,
            initialValue: selected.text,
            style: GoogleFonts.literata(color: albumInk, fontSize: 16),
            decoration: const InputDecoration(labelText: photoAddText),
            onChanged: (value) => _previewText(model, value),
          ),
          Text(photoSizeLabel),
          Slider(
            value: selected.fontSize,
            min: 16,
            max: 96,
            label: photoSizeLabel,
            onChanged: enabled
                ? (value) => _setModel(model.setSelectedSize(value))
                : null,
          ),
          Text(photoColorLabel),
          Wrap(
            children: [
              for (final swatch in TextSwatch.values)
                IconButton(
                  tooltip: photoSwatchNames[swatch],
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: enabled
                      ? () => _setModel(model.setSelectedColor(swatch))
                      : null,
                  icon: Icon(Icons.circle, color: _swatchColor(swatch)),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              _nudge(
                'Move text left',
                enabled,
                () => _setModel(model.nudgeSelected(-0.05, 0)),
              ),
              _nudge(
                'Move text right',
                enabled,
                () => _setModel(model.nudgeSelected(0.05, 0)),
              ),
              TextButton(
                onPressed: enabled
                    ? () => _setModel(model.deleteSelected())
                    : null,
                child: const Text(photoDeleteText),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _adjustBody(PhotoEditModel model, bool enabled) {
    return Column(
      children: [
        Text('$photoBrightness ${model.document.brightness}'),
        Slider(
          value: model.document.brightness.toDouble(),
          min: -100,
          max: 100,
          label: photoBrightness,
          onChanged: enabled
              ? (value) => _setModel(model.setBrightness(value.round()))
              : null,
        ),
        TextButton(
          onPressed: enabled ? () => _setModel(model.resetBrightness()) : null,
          child: const Text(photoResetBrightness),
        ),
        Text('$photoContrast ${model.document.contrast}'),
        Slider(
          value: model.document.contrast.toDouble(),
          min: -100,
          max: 100,
          label: photoContrast,
          onChanged: enabled
              ? (value) => _setModel(model.setContrast(value.round()))
              : null,
        ),
        TextButton(
          onPressed: enabled ? () => _setModel(model.resetContrast()) : null,
          child: const Text(photoResetContrast),
        ),
      ],
    );
  }

  Widget _nudge(String label, bool enabled, VoidCallback onPressed) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
  }

  Widget _actions(bool enabled) {
    final model = _model;
    final canSave = enabled && model != null && model.isDirty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: enabled ? () => _setModel(model!.resetEdits()) : null,
            child: const Text(photoResetEdits),
          ),
          TextButton(
            onPressed: _phase == _EditorPhase.saving ? null : _close,
            child: const Text(photoCancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            focusNode: _saveFocus,
            style: FilledButton.styleFrom(
              backgroundColor: albumTerracotta,
              foregroundColor: albumParchment,
              minimumSize: const Size(88, 48),
            ),
            onPressed: canSave ? _save : null,
            child: const Text(photoSave),
          ),
        ],
      ),
    );
  }

  Color _swatchColor(TextSwatch swatch) {
    return switch (swatch) {
      TextSwatch.parchment => albumParchment,
      TextSwatch.ink => albumInk,
      TextSwatch.terracotta => albumTerracotta,
      TextSwatch.sage => albumSage,
      TextSwatch.branchMoss => branchMoss,
    };
  }
}

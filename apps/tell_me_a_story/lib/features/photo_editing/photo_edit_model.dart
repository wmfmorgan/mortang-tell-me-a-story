import 'dart:ui';

/// Aspect presets in tray order. Free is the opening crop.
enum CropAspect { free, original, square, fourThree, threeFour, widescreen }

/// Named text colors. The page maps these to album tokens.
enum TextSwatch { parchment, ink, terracotta, sage, branchMoss }

/// Axis-aligned crop in the rotated image, normalized to 0..1.
class CropQuad {
  const CropQuad({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Rect get rect => Rect.fromLTWH(left, top, width, height);

  CropQuad clamp() {
    final w = width.clamp(0.05, 1.0);
    final h = height.clamp(0.05, 1.0);
    final l = left.clamp(0.0, 1.0 - w);
    final t = top.clamp(0.0, 1.0 - h);
    return CropQuad(left: l, top: t, width: w, height: h);
  }

  @override
  bool operator ==(Object other) {
    return other is CropQuad &&
        _near(other.left, left) &&
        _near(other.top, top) &&
        _near(other.width, width) &&
        _near(other.height, height);
  }

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

bool _near(double a, double b) => (a - b).abs() < 0.0001;

/// One text layer. Position is the center of the layer inside the crop.
class PhotoEditLayer {
  const PhotoEditLayer({
    required this.id,
    required this.text,
    this.nx = 0.5,
    this.ny = 0.5,
    this.fontSize = 32,
    this.color = TextSwatch.ink,
  });

  final String id;
  final String text;
  final double nx;
  final double ny;
  final double fontSize;
  final TextSwatch color;

  PhotoEditLayer copyWith({
    String? text,
    double? nx,
    double? ny,
    double? fontSize,
    TextSwatch? color,
  }) {
    return PhotoEditLayer(
      id: id,
      text: text ?? this.text,
      nx: nx ?? this.nx,
      ny: ny ?? this.ny,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
    );
  }

  /// Axis-aligned bounds in crop space after the layer is placed.
  Rect boundsIn(Size crop) {
    final width = (text.isEmpty ? 1 : text.length) * fontSize * 0.5;
    final height = fontSize * 1.2;
    return Rect.fromCenter(
      center: Offset(nx * crop.width, ny * crop.height),
      width: width,
      height: height,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PhotoEditLayer &&
        other.id == id &&
        other.text == text &&
        _near(other.nx, nx) &&
        _near(other.ny, ny) &&
        _near(other.fontSize, fontSize) &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(id, text, nx, ny, fontSize, color);
}

/// Pixels the bake must redraw. Selection is not part of this value.
class PhotoEditDocument {
  const PhotoEditDocument({
    required this.imageWidth,
    required this.imageHeight,
    this.quarterTurns = 0,
    this.aspect = CropAspect.free,
    this.crop = const CropQuad(left: 0, top: 0, width: 1, height: 1),
    this.layers = const [],
    this.brightness = 0,
    this.contrast = 0,
  });

  final int imageWidth;
  final int imageHeight;
  final int quarterTurns;
  final CropAspect aspect;
  final CropQuad crop;
  final List<PhotoEditLayer> layers;
  final int brightness;
  final int contrast;

  bool get rotatedSideways => quarterTurns.isOdd;

  int get orientedWidth => rotatedSideways ? imageHeight : imageWidth;

  int get orientedHeight => rotatedSideways ? imageWidth : imageHeight;

  PhotoEditDocument copyWith({
    int? quarterTurns,
    CropAspect? aspect,
    CropQuad? crop,
    List<PhotoEditLayer>? layers,
    int? brightness,
    int? contrast,
  }) {
    return PhotoEditDocument(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      aspect: aspect ?? this.aspect,
      crop: crop ?? this.crop,
      layers: layers ?? this.layers,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! PhotoEditDocument) return false;
    if (other.imageWidth != imageWidth ||
        other.imageHeight != imageHeight ||
        other.quarterTurns != quarterTurns ||
        other.aspect != aspect ||
        other.crop != crop ||
        other.brightness != brightness ||
        other.contrast != contrast ||
        other.layers.length != layers.length) {
      return false;
    }
    for (var i = 0; i < layers.length; i++) {
      if (other.layers[i] != layers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    imageWidth,
    imageHeight,
    quarterTurns,
    aspect,
    crop,
    brightness,
    contrast,
    Object.hashAll(layers),
  );
}

/// Session history for one opened photo. Undo stores documents, not gestures.
class PhotoEditModel {
  PhotoEditModel.open({
    required int imageWidth,
    required int imageHeight,
    required this.editVersion,
  }) : opening = PhotoEditDocument(
         imageWidth: imageWidth,
         imageHeight: imageHeight,
       ),
       document = PhotoEditDocument(
         imageWidth: imageWidth,
         imageHeight: imageHeight,
       ),
       selectedLayerId = null,
       pixelsEpoch = 0,
       _undo = const [],
       _redo = const [],
       _gestureBase = null,
       _nextLayer = 1;

  PhotoEditModel._({
    required this.opening,
    required this.document,
    required this.editVersion,
    required List<PhotoEditDocument> undo,
    required List<PhotoEditDocument> redo,
    required this.selectedLayerId,
    required this.pixelsEpoch,
    required PhotoEditDocument? gestureBase,
    required int nextLayer,
  }) : _undo = undo, // ignore: prefer_initializing_formals
       _redo = redo, // ignore: prefer_initializing_formals
       _gestureBase = gestureBase, // ignore: prefer_initializing_formals
       _nextLayer = nextLayer; // ignore: prefer_initializing_formals

  final PhotoEditDocument opening;
  final PhotoEditDocument document;
  final int editVersion;
  final String? selectedLayerId;

  /// Changes when the bake must drop a cached bitmap. Selection does not.
  final int pixelsEpoch;

  final List<PhotoEditDocument> _undo;
  final List<PhotoEditDocument> _redo;
  final PhotoEditDocument? _gestureBase;
  final int _nextLayer;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isDirty => document != opening;
  List<PhotoEditDocument> get undoStack => List.unmodifiable(_undo);
  List<PhotoEditDocument> get redoStack => List.unmodifiable(_redo);

  PhotoEditLayer? get selected {
    final id = selectedLayerId;
    if (id == null) return null;
    for (final layer in document.layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  /// Crop rectangle mapped through each quarter turn, in oriented pixels.
  List<Rect> rotatedCropBounds() {
    final bounds = <Rect>[];
    var turns = document.quarterTurns;
    var crop = document.crop;
    for (var i = 0; i < 4; i++) {
      final sideways = turns.isOdd;
      final width = sideways ? document.imageHeight : document.imageWidth;
      final height = sideways ? document.imageWidth : document.imageHeight;
      bounds.add(
        Rect.fromLTWH(
          crop.left * width,
          crop.top * height,
          crop.width * width,
          crop.height * height,
        ),
      );
      crop = _rotateNormalized(crop);
      turns = (turns + 1) % 4;
    }
    return bounds;
  }

  PhotoEditModel rotateLeft() => _rotate(-1);

  PhotoEditModel rotateRight() => _rotate(1);

  PhotoEditModel setAspect(CropAspect aspect) {
    final crop = _maxCrop(aspect, document);
    return _commit(document.copyWith(aspect: aspect, crop: crop));
  }

  PhotoEditModel setCrop(CropQuad crop) {
    return _commit(document.copyWith(crop: crop.clamp()));
  }

  PhotoEditModel recenterCrop() {
    return _commit(
      document.copyWith(crop: _maxCrop(document.aspect, document)),
    );
  }

  PhotoEditModel setBrightness(int value) {
    return _commit(document.copyWith(brightness: value.clamp(-100, 100)));
  }

  PhotoEditModel setContrast(int value) {
    return _commit(document.copyWith(contrast: value.clamp(-100, 100)));
  }

  PhotoEditModel resetBrightness() {
    if (document.brightness == 0) return this;
    return _commit(document.copyWith(brightness: 0));
  }

  PhotoEditModel resetContrast() {
    if (document.contrast == 0) return this;
    return _commit(document.copyWith(contrast: 0));
  }

  PhotoEditModel addText() {
    final id = 't$_nextLayer';
    final layer = PhotoEditLayer(id: id, text: '');
    return _commit(document.copyWith(layers: [...document.layers, layer]))
        ._copy(selectedLayerId: id, nextLayer: _nextLayer + 1);
  }

  PhotoEditModel select(String? id) {
    if (id == selectedLayerId) return this;
    return _copy(selectedLayerId: id);
  }

  PhotoEditModel editSelectedText(String text) {
    return _updateSelected((layer) => layer.copyWith(text: text));
  }

  PhotoEditModel setSelectedSize(double size) {
    final next = size.clamp(16, 96).toDouble();
    return _updateSelected((layer) => layer.copyWith(fontSize: next));
  }

  PhotoEditModel setSelectedColor(TextSwatch color) {
    return _updateSelected((layer) => layer.copyWith(color: color));
  }

  PhotoEditModel nudgeSelected(double dx, double dy) {
    return _updateSelected(
      (layer) => layer.copyWith(
        nx: (layer.nx + dx).clamp(0.0, 1.0),
        ny: (layer.ny + dy).clamp(0.0, 1.0),
      ),
    );
  }

  PhotoEditModel deleteSelected() {
    final id = selectedLayerId;
    if (id == null) return this;
    return _commit(
      document.copyWith(
        layers: [
          for (final layer in document.layers)
            if (layer.id != id) layer,
        ],
      ),
    )._copy(clearSelection: true);
  }

  /// Groups a drag into one undo step. Preview calls do not push history.
  PhotoEditModel beginGesture() {
    if (_gestureBase != null) return this;
    return _copy(gestureBase: document);
  }

  PhotoEditModel previewDocument(PhotoEditDocument next) {
    if (next == document) return this;
    final base = _gestureBase ?? document;
    return _copy(
      document: next,
      gestureBase: base,
      pixelsEpoch: pixelsEpoch + 1,
    );
  }

  PhotoEditModel endGesture() {
    final base = _gestureBase;
    if (base == null) return this;
    if (base == document) return _copy(clearGesture: true);
    return _copy(undo: [..._undo, base], redo: const [], clearGesture: true);
  }

  PhotoEditModel undo() {
    if (_undo.isEmpty) return this;
    final previous = _undo.last;
    return _copy(
      document: previous,
      undo: _undo.sublist(0, _undo.length - 1),
      redo: [..._redo, document],
      pixelsEpoch: pixelsEpoch + 1,
      clearGesture: true,
    );
  }

  PhotoEditModel redo() {
    if (_redo.isEmpty) return this;
    final next = _redo.last;
    return _copy(
      document: next,
      undo: [..._undo, document],
      redo: _redo.sublist(0, _redo.length - 1),
      pixelsEpoch: pixelsEpoch + 1,
      clearGesture: true,
    );
  }

  /// One undoable return to the document from when the editor opened.
  PhotoEditModel resetEdits() {
    if (document == opening) return this;
    return _copy(
      document: opening,
      undo: [..._undo, document],
      redo: const [],
      clearSelection: true,
      pixelsEpoch: pixelsEpoch + 1,
      clearGesture: true,
    );
  }

  PhotoEditModel _rotate(int direction) {
    final turns = (document.quarterTurns + direction) % 4;
    final normalized = turns < 0 ? turns + 4 : turns;
    final crop = direction > 0
        ? _rotateNormalized(document.crop)
        : _rotateNormalizedCounter(document.crop);
    return _commit(
      document.copyWith(quarterTurns: normalized, crop: crop.clamp()),
    );
  }

  PhotoEditModel _updateSelected(
    PhotoEditLayer Function(PhotoEditLayer) change,
  ) {
    final id = selectedLayerId;
    if (id == null) return this;
    final layers = [
      for (final layer in document.layers)
        if (layer.id == id) change(layer) else layer,
    ];
    return _commit(document.copyWith(layers: layers));
  }

  PhotoEditModel _commit(PhotoEditDocument next) {
    if (next == document) return this;
    return _copy(
      document: next,
      undo: [..._undo, document],
      redo: const [],
      pixelsEpoch: pixelsEpoch + 1,
      clearGesture: true,
    );
  }

  PhotoEditModel _copy({
    PhotoEditDocument? document,
    List<PhotoEditDocument>? undo,
    List<PhotoEditDocument>? redo,
    String? selectedLayerId,
    bool clearSelection = false,
    int? pixelsEpoch,
    PhotoEditDocument? gestureBase,
    bool clearGesture = false,
    int? nextLayer,
  }) {
    return PhotoEditModel._(
      opening: opening,
      document: document ?? this.document,
      editVersion: editVersion,
      undo: undo ?? _undo,
      redo: redo ?? _redo,
      selectedLayerId: clearSelection
          ? null
          : (selectedLayerId ?? this.selectedLayerId),
      pixelsEpoch: pixelsEpoch ?? this.pixelsEpoch,
      gestureBase: clearGesture ? null : (gestureBase ?? _gestureBase),
      nextLayer: nextLayer ?? _nextLayer,
    );
  }
}

CropQuad _rotateNormalized(CropQuad crop) {
  return CropQuad(
    left: 1 - (crop.top + crop.height),
    top: crop.left,
    width: crop.height,
    height: crop.width,
  );
}

CropQuad _rotateNormalizedCounter(CropQuad crop) {
  return CropQuad(
    left: crop.top,
    top: 1 - (crop.left + crop.width),
    width: crop.height,
    height: crop.width,
  );
}

CropQuad _maxCrop(CropAspect aspect, PhotoEditDocument document) {
  if (aspect == CropAspect.free) {
    return const CropQuad(left: 0, top: 0, width: 1, height: 1);
  }
  final ratio = switch (aspect) {
    CropAspect.free => 1.0,
    CropAspect.original => document.imageWidth / document.imageHeight,
    CropAspect.square => 1.0,
    CropAspect.fourThree => 4 / 3,
    CropAspect.threeFour => 3 / 4,
    CropAspect.widescreen => 16 / 9,
  };
  final orientedRatio = document.orientedWidth / document.orientedHeight;
  late final double width;
  late final double height;
  if (ratio >= orientedRatio) {
    width = 1;
    height = orientedRatio / ratio;
  } else {
    height = 1;
    width = ratio / orientedRatio;
  }
  return CropQuad(
    left: (1 - width) / 2,
    top: (1 - height) / 2,
    width: width,
    height: height,
  );
}

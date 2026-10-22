import 'dart:js_interop';

import 'unsaved_guard.dart';

@JS('window')
external JSObject get _window;

extension type _Window(JSObject _) implements JSObject {
  external void addEventListener(JSString type, JSFunction listener);
}

extension type _BeforeUnloadEvent(JSObject _) implements JSObject {
  external void preventDefault();
  external set returnValue(JSString value);
}

void _onBeforeUnload(JSObject event) {
  if (!UnsavedGuards.anyExitDirty) return;
  final before = _BeforeUnloadEvent(event);
  before.preventDefault();
  before.returnValue = ''.toJS;
}

void installBeforeUnloadGuard() {
  _Window(_window).addEventListener('beforeunload'.toJS, _onBeforeUnload.toJS);
}

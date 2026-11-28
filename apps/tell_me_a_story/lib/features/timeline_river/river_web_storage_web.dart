import 'dart:js_interop';

String? readWebStorage(String key) => _lsGet(key.toJS)?.toDart;

void writeWebStorage(String key, String value) {
  _lsSet(key.toJS, value.toJS);
}

@JS('localStorage.getItem')
external JSString? _lsGet(JSString key);

@JS('localStorage.setItem')
external void _lsSet(JSString key, JSString value);

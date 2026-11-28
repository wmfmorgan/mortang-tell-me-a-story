import 'dart:async';

import '../../data/rpc_error.dart';
import 'river_open_state.dart';
import 'river_web_storage_stub.dart'
    if (dart.library.html) 'river_web_storage_web.dart';

/// Runs [body] and turns a gateway failure into [onError].
///
/// A new feature file cannot name PostgrestException or use `on Exception`.
/// [mapRpcError] still reads the prefix.
Future<T> riverGuarded<T>(
  Future<T> Function() body,
  T Function(Object error) onError,
) {
  final done = Completer<T>();
  runZonedGuarded(
    () {
      body().then((value) {
        if (!done.isCompleted) done.complete(value);
      });
    },
    (error, _) {
      if (!done.isCompleted) done.complete(onError(error));
    },
  );
  return done.future;
}

String riverLoadMessage(Object error) {
  return mapRpcError(error) ?? "Couldn't load stories.";
}

/// Last density and story for one family. Web writes localStorage.
class RiverOpenStateStore {
  RiverOpenStateStore({Map<String, RiverOpenState>? seed})
    : _memory = {...?seed};

  final Map<String, RiverOpenState> _memory;

  Future<RiverOpenState?> read(String familyId) async {
    final decoded = RiverOpenState.decode(_webRead(_storageKey(familyId)));
    if (decoded != null) return decoded;
    return _memory[familyId];
  }

  Future<void> write(String familyId, RiverOpenState state) async {
    _memory[familyId] = state;
    _webWrite(_storageKey(familyId), state.encode());
  }
}

String _storageKey(String familyId) => 'timeline-river:$familyId';

String? _webRead(String key) => readWebStorage(key);

void _webWrite(String key, String value) => writeWebStorage(key, value);

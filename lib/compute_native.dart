import 'package:flutter/foundation.dart';

import 'src/rust/frb_generated.dart';

export 'compute_rust.dart' show fareFor, decodePolyline;

bool _ready = false;
bool get enabled => _ready;

Future<void> initializeCompute() async {
  if (_ready ||
      !const bool.fromEnvironment('USE_RUST') ||
      defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    await RustLib.init();
    _ready = true;
  } catch (error) {
    debugPrint('Rust compute initialization failed; using Dart: $error');
  }
}


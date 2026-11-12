import 'package:latlong2/latlong.dart';

import 'compute_dart.dart' as dart;
import 'compute_stub.dart' if (dart.library.io) 'compute_native.dart' as native;

export 'compute_dart.dart' show baseFare, perMile, milesPerKm;

/// Web always uses Dart. Android opts in with --dart-define=USE_RUST=true.
Future<void> initializeCompute() => native.initializeCompute();

bool get rustComputeEnabled => native.enabled;

double fareFor(double km) =>
    native.enabled ? native.fareFor(km) : dart.fareForDart(km);

List<LatLng> decodePolyline(String s, {int precision = 6}) => native.enabled
    ? native.decodePolyline(s, precision: precision)
    : dart.decodePolylineDart(s, precision: precision);

import 'package:latlong2/latlong.dart';

bool get enabled => false;
Future<void> initializeCompute() async {}
double fareFor(double km) => throw StateError('Rust unavailable on Web');
List<LatLng> decodePolyline(String s, {int precision = 6}) =>
    throw StateError('Rust unavailable on Web');

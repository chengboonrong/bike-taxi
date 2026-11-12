import 'package:latlong2/latlong.dart';

import 'src/rust/api/compute.dart' as rust;

double fareFor(double km) {
  // Preserve the previous Dart exception for non-finite/overflowed prices.
  if (!((2.5 + 1.5 * km * 0.621371) * 10).isFinite) {
    throw UnsupportedError('non-finite fare');
  }
  return rust.fareFor(km: km);
}

List<LatLng> decodePolyline(String s, {int precision = 6}) {
  if (precision != 5 && precision != 6) {
    throw const FormatException('precision must be 5 or 6');
  }
  try {
    final pairs = rust.decodePolyline(encoded: s, precision: precision);
    return [
      for (var i = 0; i < pairs.length; i += 2) LatLng(pairs[i], pairs[i + 1]),
    ];
  } on String catch (error) {
    throw FormatException(error);
  }
}

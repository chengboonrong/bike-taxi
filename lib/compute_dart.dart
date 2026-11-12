// Pure Dart reference implementation, also used by Flutter Web.
import 'package:latlong2/latlong.dart';

const baseFare = 2.5;
const perMile = 1.5;
const milesPerKm = 0.621371;

/// $2.50 + $1.50 a mile, rounded to 10 cents. Distances are stored in km.
double fareForDart(double km) =>
    ((baseFare + perMile * km * milesPerKm) * 10).round() / 10;

/// Decodes precision 5/6; rejects malformed input before constructing coordinates.
List<LatLng> decodePolylineDart(String s, {int precision = 6}) {
  if (precision != 5 && precision != 6) {
    throw const FormatException('precision must be 5 or 6');
  }
  final factor = precision == 5 ? 100000 : 1000000;
  final points = <LatLng>[];
  var i = 0, lat = 0, lon = 0;
  int next() {
    var result = 0;
    for (var shift = 0; shift < 30; shift += 5) {
      if (i == s.length) throw const FormatException('truncated polyline');
      final code = s.codeUnitAt(i++);
      if (code < 63 || code > 126) {
        throw const FormatException('invalid polyline character');
      }
      final b = code - 63;
      result |= (b & 0x1f) << shift;
      if (b < 0x20) return result & 1 == 1 ? ~(result >> 1) : result >> 1;
    }
    throw const FormatException('polyline component too long');
  }

  while (i < s.length) {
    lat += next();
    lon += next();
    if (lat.abs() > 90 * factor || lon.abs() > 180 * factor) {
      throw const FormatException('coordinate out of range');
    }
    points.add(LatLng(lat / factor, lon / factor));
  }
  return points;
}

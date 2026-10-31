// Road routes from Valhalla (https://github.com/valhalla/valhalla).
import 'dart:convert';
import 'dart:math' show pow;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'common.dart' show emulatorHost;

const _valhallaUrl = String.fromEnvironment('VALHALLA_URL');

// ponytail: the public FOSSGIS server is for light use only; run your own Valhalla before launch.
final _base = _valhallaUrl.isNotEmpty
    ? _valhallaUrl
    : emulatorHost.isNotEmpty
        ? 'http://$emulatorHost:8002'
        : 'https://valhalla1.openstreetmap.de';

typedef RideRoute = ({List<LatLng> points, double km, int minutes, String encoded});

/// A routing failure with a message for the rider.
class RouteException implements Exception {
  const RouteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The motorcycle road route from [a] to [b].
Future<RideRoute> routeBetween(LatLng a, LatLng b) async {
  Map<String, dynamic> body;
  try {
    final res = await http
        .post(
          Uri.parse('$_base/route'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'locations': [
              for (final p in [a, b])
                {'lat': p.latitude, 'lon': p.longitude, 'search_cutoff': 300},
            ],
            'costing': 'motorcycle',
            'units': 'kilometers',
            'directions_type': 'none',
          }),
        )
        .timeout(const Duration(seconds: 15));
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw const RouteException("Can't reach the routing service");
  }
  final trip = body['trip'];
  if (trip is! Map || trip['status'] != 0) {
    throw RouteException(switch (body['error_code']) {
      171 => 'Move the pin closer to a street',
      442 => 'No road route between these stops',
      _ => "Can't reach the routing service",
    });
  }
  final encoded = trip['legs'][0]['shape'] as String;
  final summary = trip['summary'];
  return (
    points: decodePolyline(encoded),
    km: (summary['length'] as num).toDouble(),
    minutes: ((summary['time'] as num) / 60).ceil(),
    encoded: encoded,
  );
}

/// Decodes an encoded polyline; Valhalla uses precision 6, Google precision 5.
List<LatLng> decodePolyline(String s, {int precision = 6}) {
  final factor = pow(10, precision);
  final points = <LatLng>[];
  var i = 0, lat = 0, lon = 0;
  int next() {
    var shift = 0, result = 0, b = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return result & 1 == 1 ? ~(result >> 1) : result >> 1;
  }

  while (i < s.length) {
    lat += next();
    lon += next();
    points.add(LatLng(lat / factor, lon / factor));
  }
  return points;
}

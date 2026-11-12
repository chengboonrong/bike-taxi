import 'dart:convert';
import 'dart:math';

import 'package:bike_taxi/compute_dart.dart';
import 'package:bike_taxi/compute_rust.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'fixtures/compute_fixture.dart';

final computeFixture = jsonDecode(computeFixtureJson) as Map<String, dynamic>;

// The original decoder, retained only as a valid-input compatibility oracle.
List<LatLng> legacyDecode(String s, int precision) {
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

String encodePoints(List<LatLng> points, int precision) {
  final out = StringBuffer();
  final factor = pow(10, precision);
  var lat = 0, lon = 0;
  for (final point in points) {
    final a = (point.latitude * factor).round();
    final b = (point.longitude * factor).round();
    for (final delta in [a - lat, b - lon]) {
      var value = delta < 0 ? ~(delta << 1) : delta << 1;
      while (value >= 32) {
        out.writeCharCode((value & 31 | 32) + 63);
        value >>= 5;
      }
      out.writeCharCode(value + 63);
    }
    lat = a;
    lon = b;
  }
  return out.toString();
}

void registerComputeContract() {
  test(
    'captured routes match original coordinates exactly at precision 5/6',
    () {
      for (final route in computeFixture['routes']) {
        final encoded = route['encoded'] as String;
        final precision = route['precision'] as int;
        final expected = legacyDecode(encoded, precision);
        expect(expected.length, route['pointCount']);
        expect(decodePolylineDart(encoded, precision: precision), expected);
        expect(rust.decodePolyline(encoded, precision: precision), expected);
        expect(rust.decodePolyline(encoded, precision: precision), expected);
      }
    },
  );

  test('empty, duplicate, negative deltas, poles and dateline match', () {
    final random = Random(725);
    final points = [
      const LatLng(90, 180),
      const LatLng(-90, -180),
      const LatLng(0, 0),
      const LatLng(0, 0),
      for (var i = 0; i < 1000; i++)
        LatLng(random.nextDouble() * 180 - 90, random.nextDouble() * 360 - 180),
    ];
    for (final precision in [5, 6]) {
      expect(rust.decodePolyline('', precision: precision), isEmpty);
      final encoded = encodePoints(points, precision);
      final expected = legacyDecode(encoded, precision);
      expect(decodePolylineDart(encoded, precision: precision), expected);
      expect(rust.decodePolyline(encoded, precision: precision), expected);
    }
  });

  test('malformed input has the same deterministic FormatException', () {
    const cases = {
      '?': 'truncated polyline',
      '_': 'truncated polyline',
      '<?': 'invalid polyline character',
      '\u007f?': 'invalid polyline character',
      'é?': 'invalid polyline character',
      '______?': 'polyline component too long',
      '~~~~~~?': 'polyline component too long',
      '~~~~~^?': 'coordinate out of range',
    };
    for (final decode in [decodePolylineDart, rust.decodePolyline]) {
      for (final entry in cases.entries) {
        expect(
          () => decode(entry.key),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              entry.value,
            ),
          ),
        );
      }
      for (final precision in [-1, 0, 4, 7, 256]) {
        expect(() => decode('', precision: precision), throwsFormatException);
      }
    }
  });

  test(
    'fare parity preserves original formula, rounding and stored double',
    () {
      final random = Random(725);
      final distances = <double>[
        0, -0.0, 1, 1.472, 6.833, 15.698, 1000, -3, -1e18, 1e18,
        for (final driver in computeFixture['drivers'])
          (driver['distanceKm'] as num).toDouble(),
        for (var i = 0; i < 10000; i++) random.nextDouble() * 1000,
        // Probe both sides of every 10-cent boundary through a 100-km ride.
        for (var tenth = -960; tenth < 960; tenth++)
          for (final epsilon in [-1e-12, 0.0, 1e-12])
            ((tenth + 0.5) / 10 - 2.5) / (1.5 * 0.621371) + epsilon,
      ];
      for (final km in distances) {
        final original = ((2.5 + 1.5 * km * 0.621371) * 10).round() / 10;
        expect(fareForDart(km), original, reason: 'Dart km=$km');
        final actual = rust.fareFor(km);
        expect(actual, original, reason: 'Rust km=$km');
        expect(
          jsonDecode(jsonEncode({'distanceKm': km, 'fare': actual}))['fare'],
          original,
        );
        if (km >= 0 && km <= 1000) {
          expect(
            (actual - (2.5 + 1.5 * km * 0.621371)).abs(),
            lessThanOrEqualTo(0.06),
          );
        }
      }
      for (final km in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        double.maxFinite,
      ]) {
        expect(() => fareForDart(km), throwsUnsupportedError);
        expect(() => rust.fareFor(km), throwsUnsupportedError);
      }
    },
  );
}

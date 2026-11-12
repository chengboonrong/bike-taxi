import 'dart:convert';

import 'package:bike_taxi/compute.dart';
import 'package:bike_taxi/compute_dart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/compute_fixture.dart';

void main() {
  test(
    'Web fallback reconstructs signed coordinates for all captured routes',
    () {
      final fixture = jsonDecode(computeFixtureJson) as Map<String, dynamic>;
      for (final route in fixture['routes']) {
        final points = decodePolyline(
          route['encoded'],
          precision: route['precision'],
        );
        expect(points.length, route['pointCount']);
        expect([points.first.latitude, points.first.longitude], route['first']);
        expect([points.last.latitude, points.last.longitude], route['last']);
      }
    },
  );
  test(
    'default host and Web keep Dart without native initialization',
    () async {
      await initializeCompute();
      expect(rustComputeEnabled, isFalse);
      expect(fareFor(6.833), fareForDart(6.833));
      expect(decodePolyline('????'), decodePolylineDart('????'));
      expect(() => decodePolyline('?'), throwsFormatException);
    },
  );
}

// Shared by the host AOT runner and the Android release integration runner.
import 'dart:convert';

import 'package:bike_taxi/compute_dart.dart' as dart;
import 'package:bike_taxi/compute_rust.dart' as rust;
import 'package:latlong2/latlong.dart';

import '../test/fixtures/compute_fixture.dart';

typedef Decoder = List<LatLng> Function(String s, {int precision});

double _consume(List<LatLng> points) {
  var checksum = 0.0;
  for (final p in points) {
    checksum += p.latitude + p.longitude;
  }
  return checksum;
}

Map<String, Object> benchmarkCompute({required String environment}) {
  final fixture = jsonDecode(computeFixtureJson) as Map<String, dynamic>;
  final routes = (fixture['routes'] as List).cast<Map<String, dynamic>>();
  final drivers = (fixture['drivers'] as List).cast<Map<String, dynamic>>();
  final results = <Map<String, Object>>[];
  var sink = 0.0;

  void compare(
    String name,
    double Function() dartWork,
    double Function() rustWork,
  ) {
    double measure(double Function() work, int iterations) {
      var checksum = 0.0;
      final watch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        checksum += work();
      }
      watch.stop();
      sink += checksum;
      return watch.elapsedMicroseconds / iterations;
    }

    if (dartWork() != rustWork()) {
      throw StateError('Benchmark parity failed: $name');
    }
    // Calibrate until either backend takes >=20ms; use equal batch counts.
    var iterations = 1;
    while (iterations < 65536) {
      final dartUs = measure(dartWork, iterations) * iterations;
      final rustUs = measure(rustWork, iterations) * iterations;
      if (dartUs >= 20000 || rustUs >= 20000) break;
      iterations *= 2;
    }
    for (var i = 0; i < 5; i++) {
      measure(dartWork, iterations);
      measure(rustWork, iterations);
    }
    final samples = {'dart': <double>[], 'rust': <double>[]};
    for (var sample = 0; sample < 15; sample++) {
      final order = sample.isEven ? ['dart', 'rust'] : ['rust', 'dart'];
      for (final backend in order) {
        samples[backend]!.add(
          measure(backend == 'dart' ? dartWork : rustWork, iterations),
        );
      }
    }
    Map<String, Object> describe(List<double> values) {
      final sorted = [...values]..sort();
      return {
        'median_us': sorted[7],
        'p95_us': sorted[14],
        'samples_us': values,
      };
    }

    results.add({
      'workload': name,
      'iterations_per_sample': iterations,
      'dart': describe(samples['dart']!),
      'rust': describe(samples['rust']!),
    });
  }

  for (final route in routes) {
    final encoded = route['encoded'] as String;
    final precision = route['precision'] as int;
    compare(
      'decode_${route['name']}_${route['pointCount']}_points',
      () => _consume(dart.decodePolylineDart(encoded, precision: precision)),
      () => _consume(rust.decodePolyline(encoded, precision: precision)),
    );
  }
  final distances = [
    for (final d in drivers) (d['distanceKm'] as num).toDouble(),
  ];
  compare(
    'single_fare_1.472_km',
    () => dart.fareForDart(1.472),
    () => rust.fareFor(1.472),
  );
  double fares(double Function(double) fare) {
    var checksum = 0.0;
    for (final km in distances) {
      checksum += fare(km);
    }
    return checksum;
  }

  compare(
    'fares_100_synthetic_driver_trips',
    () => fares(dart.fareForDart),
    () => fares(rust.fareFor),
  );

  double driverRefresh(Decoder decode) {
    var checksum = 0.0;
    for (var i = 0; i < drivers.length; i++) {
      final route =
          routes[drivers[i]['routeIndex'] as int]; // Recorded route assignment.
      checksum += _consume(decode(route['encoded'] as String, precision: 6));
    }
    return checksum;
  }

  compare(
    '100_driver_route_updates',
    () => driverRefresh(dart.decodePolylineDart),
    () => driverRefresh(rust.decodePolyline),
  );

  return {
    'environment': environment,
    'warmup_batches': 5,
    'samples': 15,
    'units': 'microseconds per workload',
    'includes':
        'FRB serialization, native call, result conversion to LatLng, full checksum consumption',
    'excludes': 'startup, I/O, Firebase, HTTP, UI rendering',
    'results': results,
    'checksum_sink': sink,
  };
}

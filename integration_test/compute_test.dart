import 'dart:convert';

import 'package:bike_taxi/compute.dart';
import 'package:bike_taxi/routing.dart' as routing;
import 'package:bike_taxi/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

import '../test/compute_contract.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeCompute();
    expect(rustComputeEnabled, const bool.fromEnvironment('USE_RUST'));
    if (!rustComputeEnabled) await RustLib.init();
  });
  registerComputeContract();

  test(
    'Valhalla response flows through selected backend to ride fields',
    () async {
      final fixture = computeFixture['routes'][0];
      await http.runWithClient(
        () async {
          final route = await routing.routeBetween(
            const LatLng(40.7549, -73.9840),
            const LatLng(40.7506, -73.9935),
          );
          expect(route.encoded, fixture['encoded']);
          expect(route.points.length, fixture['pointCount']);
          expect(route.km, fixture['km']);
          expect(route.minutes, ((fixture['seconds'] as num) / 60).ceil());
          // These retain the existing Firestore double fields and encoded string.
          final fields = {
            'distanceKm': route.km,
            'fare': fareFor(route.km),
            'route': route.encoded,
          };
          expect(fields['fare'], 3.9);
          expect(fields['fare'], isA<double>());
          expect(
            ((fields['fare'] as double) - (2.5 + 1.5 * route.km * 0.621371))
                .abs(),
            lessThanOrEqualTo(0.06),
          );
          expect(
            routing.decodePolyline(fields['route'] as String),
            route.points,
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/route');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'locations': [
              {'lat': 40.7549, 'lon': -73.9840, 'search_cutoff': 300},
              {'lat': 40.7506, 'lon': -73.9935, 'search_cutoff': 300},
            ],
            'costing': 'motorcycle',
            'units': 'kilometers',
            'directions_type': 'none',
          });
          return http.Response(
            jsonEncode({
              'trip': {
                'status': 0,
                'legs': [
                  {'shape': fixture['encoded']},
                ],
                'summary': {
                  'length': fixture['km'],
                  'time': fixture['seconds'],
                },
              },
            }),
            200,
          );
        }),
      );
    },
  );
}

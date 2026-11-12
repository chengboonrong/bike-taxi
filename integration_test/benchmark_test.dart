import 'dart:convert';
import 'dart:io';

import 'package:bike_taxi/compute.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/compute_benchmark.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('measure Dart and Rust through the packaged native library', (
    tester,
  ) async {
    await initializeCompute();
    expect(rustComputeEnabled, isTrue);
    final results = benchmarkCompute(
      environment: 'Android profile AOT ${Platform.version}',
    );
    binding.reportData = results;
    // The driver also saves reportData; this line makes raw results easy to recover.
    // ignore: avoid_print
    print('COMPUTE_BENCHMARK_JSON=${jsonEncode(results)}');
  });
}
